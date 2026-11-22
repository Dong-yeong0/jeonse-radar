import os
from datetime import timedelta

from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import Param, dag, get_current_context, task
from airflow.sdk.exceptions import AirflowFailException

from ingestion import row_house_transactions


@dag(
    schedule=None,
    catchup=False,
    params={
        "sigungu_code": Param("11500", type="string", pattern=r"^\d{5}$"),
        "deal_year_month": Param("202410", type="string", pattern=r"^\d{6}$"),
    },
    tags=["row_house_transactions"],
)
def ingest_row_house_transactions():
    @task(retries=3, retry_delay=timedelta(minutes=1), retry_exponential_backoff=True)
    def ingest(service):
        params = get_current_context()["params"]
        try:
            items = row_house_transactions.fetch(
                service,
                params["sigungu_code"],
                params["deal_year_month"],
                os.environ["PUBLIC_DATA_PORTAL_API_KEY"],
            )
        except row_house_transactions.ApiError as error:
            if error.code == row_house_transactions.DAILY_LIMIT_CODE:
                raise AirflowFailException(str(error)) from error
            raise
        conn = PostgresHook(postgres_conn_id="warehouse").get_conn()
        try:
            row_house_transactions.load_partition(
                conn, service, params["sigungu_code"], params["deal_year_month"], items
            )
        finally:
            conn.close()
        return len(items)

    ingest.expand(service=list(row_house_transactions.SERVICES))


ingest_row_house_transactions()
