from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import Param, dag, get_current_context, task

from assets import HOUSING_PUBLIC_PRICES
from ingestion import housing_public_prices

DATA_DIR = "/opt/airflow/data"


@dag(
    schedule=None,
    catchup=False,
    params={
        "file_name": Param("국토교통부_주택 공시가격 정보(2026).csv", type="string"),
        "sido_names": Param(["서울특별시"], type="array", items={"type": "string"}),
    },
    tags=["housing_public_prices"],
)
def load_housing_public_prices():
    @task(outlets=[HOUSING_PUBLIC_PRICES])
    def load():
        params = get_current_context()["params"]
        conn = PostgresHook(postgres_conn_id="warehouse").get_conn()
        try:
            return housing_public_prices.load(
                conn, f"{DATA_DIR}/{params['file_name']}", params["sido_names"]
            )
        finally:
            conn.close()

    load()


load_housing_public_prices()
