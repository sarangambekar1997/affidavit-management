from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="affidavit_dbt_pipeline",
    default_args=default_args,
    description="Run dbt transformations for affidavit management",
    schedule_interval="0 6 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "affidavit"],
) as dag:

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command="cd /opt/airflow/dbt/affidavit_dbt && dbt run --profiles-dir /home/airflow/.dbt --log-path /tmp/dbt_logs --target-path /tmp/dbt_target --no-partial-parse",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command="cd /opt/airflow/dbt/affidavit_dbt && dbt test --profiles-dir /home/airflow/.dbt --log-path /tmp/dbt_logs --target-path /tmp/dbt_target --no-partial-parse",
    )

    dbt_run >> dbt_test
