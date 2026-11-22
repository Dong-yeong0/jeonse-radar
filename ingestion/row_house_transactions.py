"""Client, parser and loader for the MOLIT row-house (villa) transaction APIs."""

import json
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

BASE_URL = "https://apis.data.go.kr/1613000"
SUCCESS_CODES = {"00", "000"}
DAILY_LIMIT_CODE = "22"

SERVICES = {
    "rent": (
        "RTMSDataSvcRHRent/getRTMSDataSvcRHRent",
        "raw.row_house_rent_transactions",
    ),
    "sale": (
        "RTMSDataSvcRHTrade2/getRTMSDataSvcRHTrade2",
        "raw.row_house_sale_transactions",
    ),
}

RAW_TABLE_DDL = """
create table if not exists {table} (
    sigungu_code text not null,
    deal_year_month text not null,
    payload jsonb not null,
    source_params jsonb not null,
    loaded_at timestamptz not null default now()
);
create index if not exists {index} on {table} (sigungu_code, deal_year_month);
"""


class ApiError(Exception):
    def __init__(self, code, message):
        super().__init__(f"data.go.kr error {code}: {message}")
        self.code = code


def parse(xml_text):
    """Return (items, total_count). Raises ApiError for either error envelope."""
    root = ET.fromstring(xml_text)
    if root.tag == "OpenAPI_ServiceResponse":
        header = root.find("cmmMsgHeader")
        raise ApiError(header.findtext("returnReasonCode"), header.findtext("errMsg"))
    code = root.findtext("header/resultCode")
    if code not in SUCCESS_CODES:
        raise ApiError(code, root.findtext("header/resultMsg"))
    items = [{child.tag: child.text for child in item} for item in root.iter("item")]
    return items, int(root.findtext("body/totalCount") or 0)


def fetch(service, sigungu_code, deal_year_month, api_key, num_of_rows=9999):
    """Fetch every page of one (sigungu, contract month) partition."""
    path, _ = SERVICES[service]
    items, page = [], 1
    while True:
        query = urllib.parse.urlencode(
            {
                "serviceKey": api_key,
                "LAWD_CD": sigungu_code,
                "DEAL_YMD": deal_year_month,
                "pageNo": page,
                "numOfRows": num_of_rows,
            }
        )
        with urllib.request.urlopen(
            f"{BASE_URL}/{path}?{query}", timeout=60
        ) as response:
            page_items, total_count = parse(response.read())
        items += page_items
        if not page_items or len(items) >= total_count:
            return items
        page += 1


def load_partition(conn, service, sigungu_code, deal_year_month, items):
    """Replace one partition in a single transaction (delete + insert)."""
    _, table = SERVICES[service]
    source_params = json.dumps(
        {"service": service, "LAWD_CD": sigungu_code, "DEAL_YMD": deal_year_month}
    )
    with conn, conn.cursor() as cursor:
        cursor.execute(
            RAW_TABLE_DDL.format(
                table=table, index=table.split(".")[1] + "_partition_idx"
            )
        )
        cursor.execute(
            f"delete from {table} where sigungu_code = %s and deal_year_month = %s",
            (sigungu_code, deal_year_month),
        )
        cursor.executemany(
            f"insert into {table}"
            " (sigungu_code, deal_year_month, payload, source_params)"
            " values (%s, %s, %s, %s)",
            [
                (
                    sigungu_code,
                    deal_year_month,
                    json.dumps(item, ensure_ascii=False),
                    source_params,
                )
                for item in items
            ],
        )
