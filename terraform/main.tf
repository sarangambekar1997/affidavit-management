terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.87"
    }
  }
}

provider "snowflake" {
  organization_name = var.snowflake_organization
  account_name      = var.snowflake_account_name
  user              = var.snowflake_user
  password          = var.snowflake_password
}

resource "snowflake_database" "affidavit_poc" {
  name    = "AFFIDAVIT_POC"
  comment = "Affidavit management POC database"
}

resource "snowflake_warehouse" "affidavit_wh" {
  name           = "AFFIDAVIT_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "Affidavit management warehouse"
}

resource "snowflake_schema" "raw" {
  database     = snowflake_database.affidavit_poc.name
  name         = "RAW"
  comment      = "Raw ingestion layer"
  is_transient = false
}

resource "snowflake_schema" "staging" {
  database     = snowflake_database.affidavit_poc.name
  name         = "STAGING"
  comment      = "dbt staging layer"
  is_transient = false
}

resource "snowflake_schema" "mart" {
  database     = snowflake_database.affidavit_poc.name
  name         = "MART"
  comment      = "dbt mart layer — reporting-ready tables"
  is_transient = false
}
