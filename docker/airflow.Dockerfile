FROM apache/airflow:3.4.0-python3.12

USER root
RUN python -m venv /opt/dbt-venv \
    && /opt/dbt-venv/bin/pip install --no-cache-dir dbt-core==1.12.7 dbt-postgres==1.11.0 \
    && chown -R airflow:0 /opt/dbt-venv
USER airflow
