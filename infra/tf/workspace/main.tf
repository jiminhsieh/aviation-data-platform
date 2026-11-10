terraform {
  required_version = "~> 1.9.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "= 1.76.0"
    }
  }
  backend "local" {}
}

provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.account_id
  auth_type  = "azure-cli"
}

provider "databricks" {
  alias     = "workspace"
  host      = var.workspace_host
  auth_type = "azure-cli"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["sit", "uat", "prod"], var.environment)
    error_message = "Select sit, uat or prod."
  }
}

variable "account_id" { type = string }
variable "metastore_id" { type = string }
variable "workspace_id" { type = number }
variable "workspace_host" { type = string }
variable "access_connector_id" { type = string }
variable "storage_account_name" { type = string }
variable "checkpoint_storage_account_name" { type = string }

variable "scientist_group" {
  type        = string
  description = "Pre-existing account group for read-only Silver and Gold access."
}

variable "atm_group" {
  type        = string
  description = "Pre-existing account group for read-only Gold access."
}

variable "atm_silver_access" {
  type    = bool
  default = false
}

variable "spark_version" {
  type        = string
  description = "Explicitly supported classic Jobs runtime; confirm with producer-to-Spark tests before creating the Silver Job."
}

variable "spark_node_type_id" {
  type        = string
  description = "Measured/available southeastasia classic Jobs node SKU."
}

locals {
  # The PoC keeps the contracted catalog name; other environments remain isolated on a shared regional metastore.
  catalog = var.environment == "sit" ? "aviation" : "aviation_${var.environment}"
  url     = "abfss://%s@${var.storage_account_name}.dfs.core.windows.net"
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.account
  workspace_id = var.workspace_id
  metastore_id = var.metastore_id
}

resource "databricks_service_principal" "stream" {
  provider     = databricks.account
  display_name = "aviation-${var.environment}-silver-stream"
}

resource "databricks_service_principal" "sql" {
  provider     = databricks.account
  display_name = "aviation-${var.environment}-gold-sql"
}

resource "databricks_mws_permission_assignment" "stream" {
  provider     = databricks.account
  workspace_id = var.workspace_id
  principal_id = databricks_service_principal.stream.id
  permissions  = ["USER"]
}

resource "databricks_mws_permission_assignment" "sql" {
  provider     = databricks.account
  workspace_id = var.workspace_id
  principal_id = databricks_service_principal.sql.id
  permissions  = ["USER"]
}

resource "databricks_entitlements" "stream" {
  provider             = databricks.workspace
  service_principal_id = databricks_service_principal.stream.id
  workspace_access     = true
  depends_on           = [databricks_mws_permission_assignment.stream]
}

resource "databricks_entitlements" "sql" {
  provider              = databricks.workspace
  service_principal_id  = databricks_service_principal.sql.id
  databricks_sql_access = true
  depends_on            = [databricks_mws_permission_assignment.sql]
}

resource "databricks_storage_credential" "this" {
  provider = databricks.workspace
  name     = "aviation-${var.environment}-connector"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }
  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "bronze" {
  provider        = databricks.workspace
  name            = "aviation-${var.environment}-bronze"
  url             = format(local.url, "bronze")
  credential_name = databricks_storage_credential.this.name
}

resource "databricks_external_location" "checkpoints" {
  provider        = databricks.workspace
  name            = "aviation-${var.environment}-checkpoints"
  url             = "abfss://checkpoints@${var.checkpoint_storage_account_name}.dfs.core.windows.net"
  credential_name = databricks_storage_credential.this.name
}

resource "databricks_external_location" "lakehouse" {
  provider        = databricks.workspace
  name            = "aviation-${var.environment}-lakehouse"
  url             = format(local.url, "lakehouse")
  credential_name = databricks_storage_credential.this.name
}

resource "databricks_catalog" "this" {
  provider       = databricks.workspace
  name           = local.catalog
  storage_root   = "${databricks_external_location.lakehouse.url}/managed"
  isolation_mode = "ISOLATED"
  comment        = "Aviation PoC (${var.environment}); platform owner. Managed Delta data; do not delete without a recovery plan."
  depends_on     = [databricks_external_location.lakehouse]

  lifecycle {
    prevent_destroy = true
  }
}

resource "databricks_schema" "this" {
  for_each = {
    bronze = "Original OpenSky response files; platform-owned, no analyst access."
    ops    = "Protected Silver streaming checkpoints; no automatic expiry."
    silver = "Typed deduplicated source snapshots, hours are full UTC timestamps."
    gold   = "Five-minute aircraft activity by registration country; physical UTC hour partitions."
  }
  provider     = databricks.workspace
  catalog_name = databricks_catalog.this.name
  name         = each.key
  comment      = each.value
}

resource "databricks_volume" "bronze" {
  provider         = databricks.workspace
  catalog_name     = databricks_catalog.this.name
  schema_name      = databricks_schema.this["bronze"].name
  name             = "opensky_states"
  volume_type      = "EXTERNAL"
  storage_location = "${databricks_external_location.bronze.url}/opensky/states"
  comment          = "Source-shaped immutable Avro, one file per source timestamp; owner: platform engineering."

  lifecycle {
    prevent_destroy = true
  }
}

resource "databricks_volume" "checkpoint" {
  provider         = databricks.workspace
  catalog_name     = databricks_catalog.this.name
  schema_name      = databricks_schema.this["ops"].name
  name             = "streaming_checkpoints"
  volume_type      = "EXTERNAL"
  storage_location = databricks_external_location.checkpoints.url
  comment          = "Protected stream progress; never auto-expire or reset on normal restart."

  lifecycle {
    prevent_destroy = true
  }
}

resource "databricks_sql_endpoint" "gold" {
  provider                  = databricks.workspace
  name                      = "aviation-${var.environment}-sql"
  cluster_size              = "2X-Small"
  warehouse_type            = "PRO"
  enable_serverless_compute = false
  max_num_clusters          = 1
  auto_stop_mins            = 10
  depends_on                = [databricks_metastore_assignment.this]
}

resource "databricks_cluster_policy" "silver" {
  provider = databricks.workspace
  name     = "aviation-${var.environment}-silver-jobs"
  definition = jsonencode({
    "spark_version" = { type = "fixed", value = var.spark_version }
    "node_type_id"  = { type = "fixed", value = var.spark_node_type_id }
    "num_workers"   = { type = "fixed", value = 1 }
  })
  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_permissions" "silver_policy" {
  provider          = databricks.workspace
  cluster_policy_id = databricks_cluster_policy.silver.id
  access_control {
    service_principal_name = databricks_service_principal.stream.application_id
    permission_level       = "CAN_USE"
  }
  depends_on = [databricks_entitlements.stream]
}

resource "databricks_permissions" "gold_warehouse" {
  provider        = databricks.workspace
  sql_endpoint_id = databricks_sql_endpoint.gold.id
  access_control {
    service_principal_name = databricks_service_principal.sql.application_id
    permission_level       = "CAN_USE"
  }
  access_control {
    group_name       = var.scientist_group
    permission_level = "CAN_USE"
  }
  access_control {
    group_name       = var.atm_group
    permission_level = "CAN_USE"
  }
  depends_on = [databricks_entitlements.sql]
}

resource "databricks_sql_table" "silver" {
  provider     = databricks.workspace
  catalog_name = databricks_catalog.this.name
  schema_name  = databricks_schema.this["silver"].name
  name         = "aircraft_states"
  table_type   = "MANAGED"
  warehouse_id = databricks_sql_endpoint.gold.id
  partitions   = ["snapshot_hour_utc"]
  comment      = "One typed observation per snapshot/ICAO24. Full-hour atomic replacements; country is source registration proxy. Owner: data engineering."

  column {
    name     = "snapshot_time"
    type     = "BIGINT"
    nullable = false
    comment  = "OpenSky source epoch seconds"
  }
  column {
    name     = "snapshot_at_utc"
    type     = "TIMESTAMP"
    nullable = false
  }
  column {
    name     = "snapshot_hour_utc"
    type     = "TIMESTAMP"
    nullable = false
    comment  = "Full UTC source hour partition"
  }
  column {
    name     = "bucket_start_utc"
    type     = "TIMESTAMP"
    nullable = false
  }
  column {
    name     = "icao24"
    type     = "STRING"
    nullable = false
  }
  column {
    name = "callsign"
    type = "STRING"
  }
  column {
    name    = "origin_country"
    type    = "STRING"
    comment = "OpenSky registration-country proxy; nullable"
  }
  column {
    name = "time_position"
    type = "BIGINT"
  }
  column {
    name = "last_contact"
    type = "BIGINT"
  }
  column {
    name = "longitude"
    type = "DOUBLE"
  }
  column {
    name = "latitude"
    type = "DOUBLE"
  }
  column {
    name    = "baro_altitude_m"
    type    = "DOUBLE"
    comment = "Nullable; metres"
  }
  column {
    name    = "geo_altitude_m"
    type    = "DOUBLE"
    comment = "Nullable; metres"
  }
  column {
    name = "on_ground"
    type = "BOOLEAN"
  }
  column {
    name = "velocity_mps"
    type = "DOUBLE"
  }
  column {
    name = "true_track_deg"
    type = "DOUBLE"
  }
  column {
    name = "vertical_rate_mps"
    type = "DOUBLE"
  }
  column {
    name = "squawk"
    type = "STRING"
  }
  column {
    name = "spi"
    type = "BOOLEAN"
  }
  column {
    name = "position_source"
    type = "INT"
  }
  column {
    name = "sensors"
    type = "ARRAY<INT>"
  }
  column {
    name    = "bronze_path"
    type    = "STRING"
    comment = "Canonical source file path"
  }
  column {
    name    = "processed_at_utc"
    type    = "TIMESTAMP"
    comment = "Processing audit time, may change on replay"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "databricks_sql_table" "gold" {
  provider     = databricks.workspace
  catalog_name = databricks_catalog.this.name
  schema_name  = databricks_schema.this["gold"].name
  name         = "aircraft_activity_5m"
  table_type   = "MANAGED"
  warehouse_id = databricks_sql_endpoint.gold.id
  partitions   = ["bucket_hour_utc"]
  comment      = "Five-minute latest-aircraft activity grouped by OpenSky registration-country proxy; barometric altitude metres, no carry across buckets. Owner: ATM steward/data engineering."

  column {
    name     = "bucket_hour_utc"
    type     = "TIMESTAMP"
    nullable = false
    comment  = "Full UTC hour physical partition"
  }
  column {
    name     = "bucket_start_utc"
    type     = "TIMESTAMP"
    nullable = false
    comment  = "Five-minute UTC logical bucket"
  }
  column {
    name     = "origin_country"
    type     = "STRING"
    nullable = false
    comment  = "Registration proxy, Unknown for blank/missing"
  }
  column {
    name     = "aircraft_count"
    type     = "BIGINT"
    nullable = false
    comment  = "Distinct ICAO24 per five-minute bucket/country"
  }
  column {
    name    = "avg_baro_altitude_m"
    type    = "DOUBLE"
    comment = "Mean of latest non-null per-aircraft barometric metres in bucket"
  }
  column {
    name     = "altitude_sample_count"
    type     = "BIGINT"
    nullable = false
  }
  column {
    name    = "last_source_time"
    type    = "BIGINT"
    comment = "Latest source epoch seconds represented in group"
  }
  column {
    name    = "updated_at_utc"
    type    = "TIMESTAMP"
    comment = "Refresh audit time, not source time"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "databricks_grants" "catalog" {
  provider = databricks.workspace
  catalog  = databricks_catalog.this.name
  dynamic "grant" {
    for_each = toset([databricks_service_principal.stream.application_id, databricks_service_principal.sql.application_id, var.scientist_group, var.atm_group])
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG"]
    }
  }
}

resource "databricks_grants" "schema" {
  provider = databricks.workspace
  for_each = {
    bronze = [databricks_service_principal.stream.application_id]
    ops    = [databricks_service_principal.stream.application_id]
    silver = [databricks_service_principal.stream.application_id, databricks_service_principal.sql.application_id, var.scientist_group, var.atm_group]
    gold   = [databricks_service_principal.sql.application_id, var.scientist_group, var.atm_group]
  }
  schema = databricks_schema.this[each.key].id
  dynamic "grant" {
    for_each = each.key == "silver" && !var.atm_silver_access ? toset([for p in each.value : p if p != var.atm_group]) : toset(each.value)
    content {
      principal  = grant.value
      privileges = ["USE_SCHEMA"]
    }
  }
}

resource "databricks_grants" "bronze" {
  provider = databricks.workspace
  volume   = databricks_volume.bronze.id
  grant {
    principal  = databricks_service_principal.stream.application_id
    privileges = ["READ_VOLUME"]
  }
}

resource "databricks_grants" "checkpoint" {
  provider = databricks.workspace
  volume   = databricks_volume.checkpoint.id
  grant {
    principal  = databricks_service_principal.stream.application_id
    privileges = ["READ_VOLUME", "WRITE_VOLUME"]
  }
}

resource "databricks_grants" "silver" {
  provider = databricks.workspace
  table    = databricks_sql_table.silver.id
  grant {
    principal  = databricks_service_principal.stream.application_id
    privileges = ["SELECT", "MODIFY"]
  }
  grant {
    principal  = databricks_service_principal.sql.application_id
    privileges = ["SELECT"]
  }
  grant {
    principal  = var.scientist_group
    privileges = ["SELECT"]
  }
  dynamic "grant" {
    for_each = var.atm_silver_access ? [var.atm_group] : []
    content {
      principal  = grant.value
      privileges = ["SELECT"]
    }
  }
}

resource "databricks_grants" "gold" {
  provider = databricks.workspace
  table    = databricks_sql_table.gold.id
  grant {
    principal  = databricks_service_principal.sql.application_id
    privileges = ["SELECT", "MODIFY"]
  }
  grant {
    principal  = var.scientist_group
    privileges = ["SELECT"]
  }
  grant {
    principal  = var.atm_group
    privileges = ["SELECT"]
  }
}

output "silver_policy_id" { value = databricks_cluster_policy.silver.id }
output "gold_warehouse_id" { value = databricks_sql_endpoint.gold.id }
output "silver_run_as" { value = databricks_service_principal.stream.application_id }
output "gold_run_as" { value = databricks_service_principal.sql.application_id }
output "catalog_name" { value = databricks_catalog.this.name }
output "bronze_volume_root" { value = databricks_volume.bronze.volume_path }
output "checkpoint_volume_root" { value = databricks_volume.checkpoint.volume_path }
