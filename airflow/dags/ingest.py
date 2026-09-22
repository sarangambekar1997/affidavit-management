import logging
from datetime import datetime, timezone

import psycopg2
import snowflake.connector
import yaml

logger = logging.getLogger(__name__)

TABLES = {
    "customers":   "CUSTOMERS",
    "accounts":    "ACCOUNTS",
    "legal_cases": "LEGAL_CASES",
    "payments":    "PAYMENTS",
}

def get_sf_conn():
    with open("/home/airflow/.dbt/profiles.yml") as f:
        profiles = yaml.safe_load(f)
    cfg = profiles["affidavit_dbt"]["outputs"]["dev"]
    return snowflake.connector.connect(
        account=cfg["account"],
        user=cfg["user"],
        password=cfg["password"],
        warehouse=cfg["warehouse"],
        database=cfg["database"],
        schema="RAW",
    )

def get_pg_conn():
    return psycopg2.connect(
        host="source_postgres",
        port=5432,
        dbname="source_db",
        user="source_user",
        password="source_pass",
    )

def run():
    loaded_at = datetime.now(timezone.utc)
    pg = get_pg_conn()
    sf = get_sf_conn()
    pg_cur = pg.cursor()
    sf_cur = sf.cursor()

    for pg_table, sf_table in TABLES.items():
        pg_cur.execute(f"SELECT * FROM {pg_table}")
        rows = pg_cur.fetchall()
        logger.info("%s: %d rows fetched from Postgres", pg_table, len(rows))

        sf_cur.execute(f"TRUNCATE TABLE AFFIDAVIT_POC.RAW.{sf_table}")

        if rows:
            rows_with_ts = [row + (loaded_at,) for row in rows]
            placeholders = ",".join(["%s"] * (len(rows[0]) + 1))
            sf_cur.executemany(
                f"INSERT INTO AFFIDAVIT_POC.RAW.{sf_table} VALUES ({placeholders})",
                rows_with_ts,
            )

        pg_count = len(rows)
        sf_cur.execute(f"SELECT COUNT(*) FROM AFFIDAVIT_POC.RAW.{sf_table}")
        sf_count = sf_cur.fetchone()[0]
        if pg_count != sf_count:
            raise ValueError(
                f"Row count mismatch for {sf_table}: pg={pg_count}, sf={sf_count}"
            )
        logger.info("%s: %d rows loaded and verified", sf_table, sf_count)

    sf.commit()
    pg_cur.close()
    sf_cur.close()
    pg.close()
    sf.close()
    logger.info("Ingestion complete. loaded_at=%s", loaded_at.isoformat())

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run()
