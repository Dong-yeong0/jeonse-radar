"""Client, parser and loader for the MOLIT row-house (villa) transaction APIs."""

import hashlib
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


def response_hash(items):
    """Hash of a partition response that ignores item order."""
    rows = sorted(
        json.dumps(item, ensure_ascii=False, sort_keys=True) for item in items
    )

    return hashlib.sha256("\n".join(rows).encode()).hexdigest()


def load_partition(conn, service, sigungu_code, deal_year_month, items):
    """Append the response as a new batch unless it equals the latest batch.

    Raw is append-only. A batch is identified by loaded_at, which is the same
    for every row inserted in one transaction.
    """
    # ponytail: an empty response inserts no rows, so a partition that drops to
    # zero rows keeps its previous batch as latest. Add a batch log table if
    # that matters.
    _, table = SERVICES[service]
    new_hash = response_hash(items)
    source_params = json.dumps(
        {"service": service, "LAWD_CD": sigungu_code, "DEAL_YMD": deal_year_month}
    )
    with conn, conn.cursor() as cursor:
        cursor.execute(
            f"SELECT response_hash FROM {table}"
            " WHERE sigungu_code = %s AND deal_year_month = %s"
            " ORDER BY loaded_at DESC LIMIT 1",
            (sigungu_code, deal_year_month),
        )
        latest = cursor.fetchone()
        if latest and latest[0] == new_hash:
            return False

        cursor.executemany(
            f"INSERT INTO {table}"
            " (sigungu_code, deal_year_month, payload, source_params, response_hash)"
            " VALUES (%s, %s, %s, %s, %s)",
            [
                (
                    sigungu_code,
                    deal_year_month,
                    json.dumps(item, ensure_ascii=False),
                    source_params,
                    new_hash,
                )
                for item in items
            ],
        )

    return True
