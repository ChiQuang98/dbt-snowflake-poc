FROM apache/airflow:2.9.1-python3.9
LABEL maintainer="Data Engineering Team"
LABEL email="taen@tokenmetrics.com"


WORKDIR ${AIRFLOW_HOME}


COPY requirements.txt .

RUN pip install --no-cache-dir "apache-airflow==2.9.1" -r requirements.txt

COPY . .

USER root
ENV PIP_USER=false
# RUN apt-get update && apt-get install -y \
#     gcc python3-dev \
#     && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PIP_USER=true
USER airflow

