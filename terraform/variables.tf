variable "snowflake_organization" {
  description = "Snowflake organization name (e.g. RVDYEUC)"
  type        = string
}

variable "snowflake_account_name" {
  description = "Snowflake account name (e.g. IA25632)"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}
