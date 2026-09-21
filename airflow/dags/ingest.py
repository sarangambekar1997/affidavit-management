import psycopg2
import snowflake.connector
import yaml

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
    pg = get_pg_conn()
    sf = get_sf_conn()
    pg_cur = pg.cursor()
    sf_cur = sf.cursor()

    for pg_table, sf_table in TABLES.items():
        pg_cur.execute(f"SELECT * FROM {pg_table}")
        rows = pg_cur.fetchall()
        print(f"{pg_table}: {len(rows)} rows fetched from Postgres")
        sf_cur.execute(f"TRUNCATE TABLE AFFIDAVIT_POC.RAW.{sf_table}")
        if rows:
            placeholders = ",".join(["%s"] * len(rows[0]))
            sf_cur.executemany(
                f"INSERT INTO AFFIDAVIT_POC.RAW.{sf_table} VALUES ({placeholders})",
                rows
            )
        print(f"{sf_table}: {len(rows)} rows loaded into Snowflake RAW")

    sf.commit()
    pg_cur.close()
    sf_cur.close()
    pg.close()
    sf.close()
    print("Ingestion complete")

if __name__ == "__main__":
    run()
