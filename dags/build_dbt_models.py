from airflow.sdk import dag, task

from assets import ROW_HOUSE_RENT_TRANSACTIONS, ROW_HOUSE_SALE_TRANSACTIONS


@dag(
    schedule=[ROW_HOUSE_RENT_TRANSACTIONS, ROW_HOUSE_SALE_TRANSACTIONS],
    catchup=False,
    max_active_runs=1,
    tags=["dbt"],
)
def build_dbt_models():
    @task.bash(cwd="/opt/airflow/dbt")
    def dbt_build():
        return "/opt/dbt-venv/bin/dbt build --exclude resource_type:seed"

    dbt_build()


build_dbt_models()
