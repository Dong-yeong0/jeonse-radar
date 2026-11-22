import os
from datetime import timedelta

import pendulum
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import Param, dag, get_current_context, task
from airflow.sdk.exceptions import AirflowFailException, AirflowSkipException

from assets import ROW_HOUSE_RENT_TRANSACTIONS, ROW_HOUSE_SALE_TRANSACTIONS
from ingestion import row_house_transactions

KST = "Asia/Seoul"


@dag(
    schedule="@monthly",
    start_date=pendulum.datetime(2015, 1, 1, tz=KST),
    catchup=False,
    max_active_runs=2,
    params={
        "sido_names": Param(["서울특별시"], type="array", items={"type": "string"}),
    },
    tags=["row_house_transactions"],
)
def ingest_row_house_transactions():
    @task
    def list_partitions():
        context = get_current_context()
        deal_year_month = context["logical_date"].in_timezone(KST).strftime("%Y%m")
        rows = PostgresHook(postgres_conn_id="warehouse").get_records(
            """
            SELECT DISTINCT left(legal_dong_code, 5)
            FROM analytics.legal_dong_codes
            WHERE sido_name = ANY(%s)
              AND legal_dong_code LIKE '%%00000'
              AND sigungu_name IS NOT NULL
            ORDER BY 1
            """,
            parameters=(context["params"]["sido_names"],),
        )

        return [
            {
                "service": service,
                "sigungu_code": sigungu_code,
                "deal_year_month": deal_year_month,
            }
            for (sigungu_code,) in rows
            for service in row_house_transactions.SERVICES
        ]

    @task(
        pool="data_go_kr_api",
        retries=3,
        retry_delay=timedelta(minutes=1),
        retry_exponential_backoff=True,
    )
    def ingest(partition):
        try:
            items = row_house_transactions.fetch(
                partition["service"],
                partition["sigungu_code"],
                partition["deal_year_month"],
                os.environ["PUBLIC_DATA_PORTAL_API_KEY"],
            )
        except row_house_transactions.ApiError as error:
            if error.code == row_house_transactions.DAILY_LIMIT_CODE:
                raise AirflowFailException(str(error)) from error

            raise

        conn = PostgresHook(postgres_conn_id="warehouse").get_conn()
        try:
            row_house_transactions.load_partition(
                conn,
                partition["service"],
                partition["sigungu_code"],
                partition["deal_year_month"],
                items,
            )
        finally:
            conn.close()

        return len(items)

    @task(outlets=[ROW_HOUSE_RENT_TRANSACTIONS, ROW_HOUSE_SALE_TRANSACTIONS])
    def publish_raw_assets(row_counts):
        if get_current_context()["dag_run"].run_type == "backfill":
            raise AirflowSkipException("backfill run, run dbt once after it finishes")

        return sum(row_counts)

    publish_raw_assets(ingest.expand(partition=list_partitions()))


ingest_row_house_transactions()
