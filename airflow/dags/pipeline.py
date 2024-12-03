from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
with DAG(
    dag_id='dbt_run_example',
    default_args=default_args,
    description='A simple DAG to run dbt commands',
    schedule_interval='@daily',
    start_date=datetime(2024, 12, 1),
    catchup=False,
    tags=['dbt', 'example'],
) as dag:

    # Task to run `dbt run`
    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/dbt && dbt run'
    )

    # Task to test dbt
    # dbt_test = BashOperator(
    #     task_id='dbt_test',
    #     bash_command='cd /opt/airflow/dbt && dbt test',
    #     env={
    #         "DBT_PROFILES_DIR": "/opt/airflow/dbt",  # Set profiles directory
    #     }
    # )

    # Define task dependencies
    dbt_run 
