# Affidavit Management Data Platform

A end-to-end data engineering pipeline that identifies affidavit candidates from a source transactional database, transforming and validating the data through a multi-layer Snowflake warehouse orchestrated by Apache Airflow.

## Architecture

```
┌─────────────────────┐
│   Source Postgres   │  Transactional source system
│  (Docker container) │  customers · accounts · legal_cases · payments
└──────────┬──────────┘
           │ Python ingestion (ingest.py)
           ▼
┌─────────────────────┐
│   Snowflake RAW     │  Raw tables, schema-on-read
│   AFFIDAVIT_POC.RAW │  CUSTOMERS · ACCOUNTS · LEGAL_CASES · PAYMENTS
└──────────┬──────────┘
           │ dbt run
           ▼
┌─────────────────────┐
│  Snowflake STAGING  │  Cleaned, typed, normalised
│   .STAGING          │  stg_customers · stg_accounts · stg_legal_cases · stg_payments
└──────────┬──────────┘
           │ dbt run
           ▼
┌─────────────────────┐
│   Snowflake MART    │  Business-logic layer
│   .MART             │  affidavit_candidates
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
| Transformation | dbt-core 1.12.3 + dbt-snowflake 1.10.8 |
| Orchestration | Apache Airflow 2.9.1 (Docker, LocalExecutor) |
| Ingestion | Python 3.12 + snowflake-connector-python + psycopg2 |
| Infrastructure | Terraform + Snowflake-Labs provider ~0.87 |
| Containerisation | Docker Compose |

## Project Structure

```
affidavit-management/
├── affidavit_dbt/                  # dbt project
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml         # RAW table source definitions
│   │   │   ├── schema.yml          # staging model tests
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_accounts.sql
│   │   │   ├── stg_legal_cases.sql
│   │   │   └── stg_payments.sql
│   │   └── mart/
│   │       ├── schema.yml          # mart model tests
│   │       └── affidavit_candidates.sql
│   ├── macros/
│   │   └── generate_schema_name.sql  # custom schema routing
│   └── dbt_project.yml
│
├── airflow/                        # Airflow Docker setup
│   ├── dags/
│   │   ├── affidavit_dbt_dag.py   # main DAG definition
│   │   └── ingest.py              # Postgres → Snowflake ingestion
│   ├── init_sql/
│   │   └── 01_seed.sql            # source database seed data
│   └── docker-compose.yaml
│
└── terraform/                      # Infrastructure as Code
    ├── main.tf                     # Snowflake resources
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars            # credentials (gitignored)
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

### 3. Start Airflow + Source Postgres

```bash
cd airflow
docker compose up airflow-init
docker compose up -d
```

Airflow UI: http://localhost:8081 (user: `airflow` / pass: `airflow`)

### 4. Run the Pipeline

Trigger the `affidavit_dbt_pipeline` DAG from the Airflow UI, or:

```bash
docker compose exec airflow-scheduler airflow dags trigger affidavit_dbt_pipeline
```

### 5. Run dbt Locally

```bash
cd affidavit_dbt
dbt run
dbt test
dbt docs serve    # opens lineage graph at localhost:8080
```

## Data Model

### RAW Layer (source-aligned)

| Table | Key columns |
|---|---|
| `CUSTOMERS` | customer_id, customer_name, state, email, created_date |
| `ACCOUNTS` | account_id, customer_id, original_creditor, balance, account_status, account_open_date |
| `LEGAL_CASES` | case_id, account_id, case_type, case_status, court_state, filing_date |
| `PAYMENTS` | payment_id, account_id, payment_date, payment_amount, payment_status |

### STAGING Layer (cleaned, typed)

One model per RAW table. Transformations applied: `TRIM()`, `UPPER()` on status/state columns, `LOWER()` on emails.

### MART Layer (business logic)

**`AFFIDAVIT_CANDIDATES`** — joins accounts + legal cases + customers, filtered by the affidavit rule. Each row represents one account eligible for affidavit processing.

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
