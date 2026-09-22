# Affidavit Management Data Platform

An end-to-end data engineering pipeline that identifies affidavit candidates from a source transactional database, transforming and validating the data through a multi-layer Snowflake warehouse orchestrated by Apache Airflow.

## Architecture

```
┌─────────────────────┐
│   Source Postgres   │  Transactional source system
│  (Docker container) │  customers · accounts · legal_cases · payments
└──────────┬──────────┘
           │ Python ingestion (ingest.py)
           │ truncate + load · LOADED_AT timestamp · row count validation
           ▼
┌─────────────────────┐
│   Snowflake RAW     │  Raw tables, schema-on-read
│   AFFIDAVIT_POC.RAW │  CUSTOMERS · ACCOUNTS · LEGAL_CASES · PAYMENTS
└──────────┬──────────┘
           │ dbt run
           ▼
┌─────────────────────┐
│  Snowflake STAGING  │  Views — cleaned, typed, normalised
│   .STAGING          │  stg_customers · stg_accounts · stg_legal_cases · stg_payments
└──────────┬──────────┘
           │ dbt run
           ▼
┌─────────────────────┐
│   Snowflake MART    │  Business-logic layer
│   .MART             │  affidavit_candidates (table)
│                     │  fct_payments (incremental)
└─────────────────────┘

Orchestration: Apache Airflow (daily @ 06:00 UTC)
DAG: ingest_to_snowflake → dbt_run → dbt_test

Infrastructure: Terraform (Snowflake database, warehouse, schemas)
```

## Affidavit Rule

An account qualifies as an affidavit candidate when all three conditions are met:

| Condition | Value |
|---|---|
| Account status | `ACTIVE` |
| Balance | `> $1,000` |
| Legal case status | `OPEN` |

## Tech Stack

| Layer | Technology |
|---|---|
| Source database | PostgreSQL 13 (Docker) |
| Data warehouse | Snowflake (XSMALL warehouse, auto-suspend 60s) |
| Transformation | dbt-core 1.12.3 + dbt-snowflake 1.10.8 + dbt_utils 1.4.1 |
| Orchestration | Apache Airflow 2.9.1 (Docker, LocalExecutor) |
| Ingestion | Python 3.12 + snowflake-connector-python + psycopg2 |
| Infrastructure | Terraform + Snowflake-Labs provider ~0.87 |
| Containerisation | Docker Compose (custom Airflow image via Dockerfile) |

## Project Structure

```
affidavit-management/
├── affidavit_dbt/                  # dbt project
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml         # RAW source definitions + freshness config
│   │   │   ├── schema.yml          # staging model tests
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_accounts.sql
│   │   │   ├── stg_legal_cases.sql
│   │   │   └── stg_payments.sql
│   │   └── mart/
│   │       ├── schema.yml          # mart model tests
│   │       ├── affidavit_candidates.sql
│   │       └── fct_payments.sql    # incremental payments fact table
│   ├── macros/
│   │   └── generate_schema_name.sql
│   ├── packages.yml                # dbt_utils dependency
│   └── dbt_project.yml
│
├── airflow/                        # Airflow Docker setup
│   ├── Dockerfile                  # custom image with baked-in dependencies
│   ├── dags/
│   │   ├── affidavit_dbt_dag.py
│   │   └── ingest.py
│   ├── init_sql/
│   │   └── 01_seed.sql
│   └── docker-compose.yaml
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
└── requirements.txt                # local development dependencies
```

## Prerequisites

- Docker Desktop (running)
- Terraform >= 1.0
- Python 3.12+ with pip
- Snowflake account with ACCOUNTADMIN access
- dbt profile configured at `~/.dbt/profiles.yml`

## Setup

### 1. Provision Snowflake Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your credentials
terraform init
terraform apply
```

### 2. Configure dbt Profile

Ensure `~/.dbt/profiles.yml` contains:

```yaml
affidavit_dbt:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your-org>-<your-account>
      user: <username>
      password: <password>
      warehouse: AFFIDAVIT_WH
      database: AFFIDAVIT_POC
      schema: RAW
```

### 3. Install Python dependencies

```bash
pip install -r requirements.txt
cd affidavit_dbt && dbt deps   # installs dbt_utils
```

### 4. Build and start Airflow + Source Postgres

```bash
cd airflow
docker compose build            # bakes requirements into the image
docker compose up airflow-init
docker compose up -d
```

Airflow UI: http://localhost:8081 (user: `airflow` / pass: `airflow`)

### 5. Run the Pipeline

Trigger the `affidavit_dbt_pipeline` DAG from the Airflow UI, or:

```bash
docker compose exec airflow-scheduler airflow dags trigger affidavit_dbt_pipeline
```

### 6. Run dbt Locally

```bash
cd affidavit_dbt
dbt run                  # runs all models
dbt test                 # runs all schema tests
dbt source freshness     # checks RAW table freshness against 25h warn / 49h error thresholds
dbt docs serve           # lineage graph at localhost:8080
```

## Data Model

### RAW Layer (source-aligned)

| Table | Key columns |
|---|---|
| `CUSTOMERS` | customer_id, customer_name, state, email, created_date, **loaded_at** |
| `ACCOUNTS` | account_id, customer_id, original_creditor, balance, account_status, account_open_date, **loaded_at** |
| `LEGAL_CASES` | case_id, account_id, case_type, case_status, court_state, filing_date, **loaded_at** |
| `PAYMENTS` | payment_id, account_id, payment_date, payment_amount, payment_status, **loaded_at** |

`loaded_at` is stamped by `ingest.py` at the start of each run and enables source freshness monitoring.

### STAGING Layer (views — cleaned, typed)

One view per RAW table. Transformations: `TRIM()`, `UPPER()` on status/state columns, `LOWER()` on emails.

### MART Layer (business logic)

| Model | Materialization | Description |
|---|---|---|
| `affidavit_candidates` | Table | Accounts eligible for affidavit processing (ACTIVE + balance > $1k + OPEN case) |
| `fct_payments` | Incremental (merge) | Payment fact table — merges only new records each run using `LOADED_AT` as watermark |

## dbt Tests

| Model | Test | Column |
|---|---|---|
| stg_customers | unique, not_null | CUSTOMER_ID |
| stg_accounts | unique, not_null | ACCOUNT_ID |
| stg_accounts | accepted_values (ACTIVE/INACTIVE/CLOSED) | ACCOUNT_STATUS |
| stg_legal_cases | unique, not_null | CASE_ID |
| stg_legal_cases | accepted_values (OPEN/CLOSED/PENDING) | CASE_STATUS |
| stg_payments | unique, not_null | PAYMENT_ID |
| affidavit_candidates | unique, not_null | ACCOUNT_ID |
| affidavit_candidates | accepted_values (ACTIVE only) | ACCOUNT_STATUS |
| affidavit_candidates | accepted_values (OPEN only) | CASE_STATUS |
| fct_payments | unique, not_null | PAYMENT_ID |
| fct_payments | not_null | ACCOUNT_ID |
| fct_payments | accepted_values (COMPLETED/PENDING/FAILED) | PAYMENT_STATUS |

## Source Freshness

dbt monitors the `LOADED_AT` column on all RAW tables and warns/errors if data is stale:

| Threshold | Behaviour |
|---|---|
| > 25 hours since last load | `WARN` |
| > 49 hours since last load | `ERROR` |

Run `dbt source freshness` at any time to check current status.

## Ingestion Details

`ingest.py` runs as the first Airflow task on each DAG execution:

- Connects to the source Postgres container
- For each table: fetches all rows, truncates the Snowflake RAW table, loads rows with a `LOADED_AT` timestamp
- Validates row counts between source and destination — raises an exception on mismatch
- Rolls back the entire Snowflake transaction if any table fails, preventing partial state
- All operations are logged at `INFO`/`ERROR` level and captured by Airflow task logs
