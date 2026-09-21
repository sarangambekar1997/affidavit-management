output "database_name" {
  value = snowflake_database.affidavit_poc.name
}

output "warehouse_name" {
  value = snowflake_warehouse.affidavit_wh.name
}

output "schemas" {
  value = [
    snowflake_schema.raw.name,
    snowflake_schema.staging.name,
    snowflake_schema.mart.name,
  ]
}
