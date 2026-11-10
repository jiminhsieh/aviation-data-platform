# Azure and governed lakehouse foundation

**Status: Terraform configuration staged; no cloud plan, apply, connectivity or role-denial test has been run.** The [Azure](azure/main.tf) and [Databricks](workspace/main.tf) roots provision the foundation only; reusable [network](modules/network/main.tf) and [storage](modules/storage/main.tf) modules are called by the Azure root. The collector Helm chart and Databricks Silver/Gold Job definitions belong to later work. See the [target design](../../references/thales-azure-data-platform-design.md) for pipeline and recovery contracts.

## Scope and ownership

| Owner | Resources |
|---|---|
| `azure/` (AzureRM 4.41.0, Terraform 1.9.x) | Per-environment `southeastasia` resource group, VNet/NSGs/reserved private subnet, one-node AKS with OIDC/Workload Identity/CSI rotation, ACR, HNS ADLS Gen2, four private containers, Key Vault, collector identity/federation/scoped RBAC, Databricks Premium workspace/Access Connector, diagnostic settings/Log Analytics. |
| `workspace/` (Databricks 1.76.0) | Existing regional metastore assignment, isolated per-environment catalog (`aviation` for sit, `aviation_uat`/`aviation_prod`), UC storage credential/locations, `bronze` and `ops` external volumes, managed Silver/Gold tables, grants, classic Jobs cluster policy and Pro SQL warehouse. |
| External operator | Register OpenSky OAuth client, inject/rotate secret values in Key Vault, bootstrap Bronze directory and manage local state/backups; never supply OpenSky secret values to Terraform. |
| Later change sections | Collector Helm owns ServiceAccount/CSI/CronJob, and transformation Job definitions own Spark/SQL tasks/schedules/checkpoints; do not duplicate these objects in Terraform or portal. |

The collector gets scoped Bronze read/write/add and quarantine read/write/add **without delete**, plus read access to named Key Vault secrets (after their creation). Azure Blob `write` still permits overwrite: the application must implement conditional create-if-absent. Databricks accesses Bronze/checkpoints/lakehouse through the Access Connector and UC, not account keys. Silver run-as gets Bronze read, checkpoint read/write and Silver select/modify; Gold run-as gets Silver select, Gold select/modify and SQL warehouse use. Data scientists get Silver/Gold SELECT; ATM gets Gold SELECT and optional Silver SELECT; neither analyst group gets Bronze/checkpoints/secrets or table MODIFY. Operators must test actual allow/deny paths before calling this least privilege verified. Public authenticated endpoints are the **PoC** trade-off; no anonymous blob access or shared storage keys.

## Prerequisites and local state

Install Terraform **1.9.x**, Azure CLI and an account-authorized Databricks operator. Sign in with `az login`, select the right Azure subscription and tenant, and confirm the target subscription, `southeastasia` resource/SKU quotas (AKS VM, Premium Databricks, Pro warehouse) and existing Unity Catalog metastore. An Azure operator needs resource provisioning/role-assignment privileges, Key Vault Secrets Officer for external secret setup and Storage Blob Data Contributor on Bronze for directory bootstrap; the Databricks account/metastore operator needs permission to assign the existing metastore, create storage credentials/locations and managed storage, and create/grant workspace objects. Pre-create or identify the scientist/ATM account groups and assign them to this workspace with Databricks SQL access; these shared group memberships/entitlements are outside the per-environment Terraform root. If the metastore is already assigned, **import** its assignment into the workspace state following the pinned provider's import instructions rather than replacing it. Existing objects should likewise be imported or reconciled before apply. Choose a Spark runtime and Jobs node type actually available in region; the stream's Avro union behavior must be tested on this pinned runtime later.

Each environment has a separate **local** backend path and Terraform data directory under a private, backed-up directory outside the repository. Checked-in, non-secret [environment inputs](environments/) provide distinct `sit`, `uat` and `prod` VNet/subnet CIDRs and environment names (which determine catalog names); each root reads its own `*.tfvars.example` through `-var-file`. Azure CIDRs are required inputs, not shared defaults. Run these commands from the repository root, one environment at a time; substitute real **non-secret** identifiers and a globally unique lowercase suffix, and review plans before applying. Never share the same state path, storage account name, cluster or catalog between environments. Do not put OpenSky credentials in `*.tfvars`, command history, logs or Git. Treat **all** Terraform state and saved plans as sensitive: providers may store computed credentials even without secret-valued inputs. Azure CLI credentials are used by the Databricks provider; the AzureRM provider also accepts normal Azure CLI authentication.

```bash
umask 077
export ENV=sit SUBSCRIPTION_ID='<subscription-uuid>' SUFFIX='<unique-lowercase-suffix>'
export ACCOUNT_ID='<databricks-account-id>' METASTORE_ID='<existing-regional-metastore-id>'
export SCIENTIST_GROUP='<existing-account-group>' ATM_GROUP='<existing-account-group>'
export SPARK_VERSION='<supported-spark-version>' SPARK_NODE_TYPE='<available-node-type>'
export STATE_ROOT="$HOME/.local/share/aviation-tf-state"
mkdir -p "$STATE_ROOT/$ENV"
chmod 700 "$STATE_ROOT" "$STATE_ROOT/$ENV"
az account set --subscription "$SUBSCRIPTION_ID"
terraform fmt -check -recursive infra/tf
```

For `uat`/`prod`, change `ENV` and choose unique names; the selected input file supplies distinct `10.42.0.0/16`, `10.43.0.0/16` or `10.44.0.0/16` VNet ranges and their subnets. Verify they do not overlap existing networks before applying; these files are examples, not a claim that your subscription can use those CIDRs. The matching workspace file selects `aviation`, `aviation_uat` or `aviation_prod`. All three environments are `southeastasia`. `terraform init` reconfigures only the selected local backend; state, backup and saved plan stay outside Git. The value of `SUFFIX` must make storage/ACR/Key Vault names globally unique and comply with Azure name lengths (storage: 3–24 lowercase letters/digits).

```bash
export TF_DATA_DIR="$STATE_ROOT/$ENV/.terraform-azure"
terraform -chdir=infra/tf/azure init -reconfigure -backend-config="path=$STATE_ROOT/$ENV/azure.tfstate"
terraform -chdir=infra/tf/azure validate
terraform -chdir=infra/tf/azure plan -out="$STATE_ROOT/$ENV/azure.tfplan" \
  -var-file="../environments/$ENV/azure.tfvars.example" -var="subscription_id=$SUBSCRIPTION_ID" \
  -var="storage_account_name=aviation${ENV}${SUFFIX}" \
  -var="acr_name=aviation${ENV}${SUFFIX}" \
  -var="key_vault_name=aviation-${ENV}-${SUFFIX}"
# Inspect the plan first: terraform -chdir=infra/tf/azure show "$STATE_ROOT/$ENV/azure.tfplan"
# Only after review: terraform -chdir=infra/tf/azure apply "$STATE_ROOT/$ENV/azure.tfplan"
```

Before `workspace/` apply, create the canonical path with the Azure CLI as a data-authorized operator (once per fresh container); these are **directories**, not `.avro` placeholder records. Read output from the applied Azure state, not a speculative plan. If a directory already exists, check it instead of overwriting any file. Assign the operator Bronze data permissions and wait for RBAC propagation first.

```bash
export STORAGE_ACCOUNT="$(terraform -chdir=infra/tf/azure output -raw storage_account_name)"
az storage fs directory create --file-system bronze --name opensky --account-name "$STORAGE_ACCOUNT" --auth-mode login
az storage fs directory create --file-system bronze --name opensky/states --account-name "$STORAGE_ACCOUNT" --auth-mode login
export TF_DATA_DIR="$STATE_ROOT/$ENV/.terraform-workspace"
terraform -chdir=infra/tf/workspace init -reconfigure -backend-config="path=$STATE_ROOT/$ENV/workspace.tfstate"
terraform -chdir=infra/tf/workspace validate
terraform -chdir=infra/tf/workspace plan -out="$STATE_ROOT/$ENV/workspace.tfplan" \
  -var-file="../environments/$ENV/workspace.tfvars.example" \
  -var="account_id=$ACCOUNT_ID" -var="metastore_id=$METASTORE_ID" \
  -var="workspace_id=$(TF_DATA_DIR="$STATE_ROOT/$ENV/.terraform-azure" terraform -chdir=infra/tf/azure output -raw workspace_id)" \
  -var="workspace_host=$(TF_DATA_DIR="$STATE_ROOT/$ENV/.terraform-azure" terraform -chdir=infra/tf/azure output -raw workspace_host)" \
  -var="access_connector_id=$(TF_DATA_DIR="$STATE_ROOT/$ENV/.terraform-azure" terraform -chdir=infra/tf/azure output -raw access_connector_id)" \
  -var="storage_account_name=$STORAGE_ACCOUNT" \
  -var="scientist_group=$SCIENTIST_GROUP" -var="atm_group=$ATM_GROUP" \
  -var="spark_version=$SPARK_VERSION" -var="spark_node_type_id=$SPARK_NODE_TYPE"
# Inspect the plan: terraform -chdir=infra/tf/workspace show "$STATE_ROOT/$ENV/workspace.tfplan"
# Only after review: terraform -chdir=infra/tf/workspace apply "$STATE_ROOT/$ENV/workspace.tfplan"
```

**Caution:** switch `TF_DATA_DIR` back to `.terraform-azure` when running `azure/` outputs/plan again; each root has its own backend initialization. If Azure state already contains the previous root resources, the nine `moved` blocks in `azure/main.tf` migrate their addresses into modules. Back up state, discard old saved plans and review a **new** plan: it must show address moves without deleting/replacing the storage account, containers or network. Stop if it does not. Avoid concurrent applies or replays against one environment. Record environment-specific variable values in an access-controlled operator inventory (not in Git). Use `terraform -chdir=infra/tf/{azure,workspace} output` to retrieve non-secret identifiers and volumes after apply. Account administrator permissions are needed only at bootstrap; workload identities must never inherit them.

## Secret bootstrap and rotation

Register the OpenSky OAuth2 client outside Terraform. An operator with Key Vault Secrets Officer creates **only** `opensky-client-id` and `opensky-client-secret` in the per-environment vault using a secure secrets tool or Azure portal; never paste their values into a Terraform variable, shell command arguments, process environment, checked-in file, plan or logging output. Start with `opensky_secret_names = []` (the default). After both secrets exist, re-plan/apply **Azure only**, repeating the same baseline `-var-file` and `-var` values above and adding `-var='opensky_secret_names=["opensky-client-id","opensky-client-secret"]'`, to scope the collector's Key Vault Secrets User role to those two secrets. Role assignment may take time to propagate. The later Helm chart must create the Kubernetes ServiceAccount `ingestion/opensky-collector`, annotate it with the `collector_client_id` output, and configure CSI to mount those names via the per-environment `key_vault_name`/`tenant_id` outputs. No literal secret values belong in Helm.

For rotation, set **new versions of the same two named secrets** using the secure tool, never update values through Terraform. Confirm the CSI-mounted versions and collector OAuth success after the AKS Secrets Store CSI rotation interval; if a client ID changes, rotate its paired secret together and allow any needed propagation before revoking the old client. Check AKS/Key Vault diagnostics for denied access **without printing or collecting mounted secret contents**. Credential registration, version changes and OpenSky Key Vault data-plane values are deliberately external to both Terraform configurations; inspect and protect state because Azure resources may expose other computed sensitive fields.

## Governance, verification and data dictionary

After apply, confirm that `bronze`, `checkpoints`, `lakehouse` and `quarantine` are private, HNS enabled, shared keys/anonymous access disabled, and the Bronze prefix exists. UC has separate external `bronze.opensky_states` and `ops.streaming_checkpoints` volumes, with managed `silver.aircraft_states` and `gold.aircraft_activity_5m`; checkpoint data must have **no automatic expiration**. The Silver policy is for **classic Jobs compute** and the Gold endpoint is a **Pro SQL warehouse**; neither schedules a pipeline here. Test authenticated AKS→Key Vault/ADLS and Databricks→ADLS access after workload deployment, and attempt denied Bronze/checkpoint/secret/table-write operations under analyst identities, not only by reading grants. An unauthenticated Blob container-list request must not return data. These checks cannot be reported as passing until an operator supplies a provisioned environment.

| Table | Physical partition | Business fields and units |
|---|---|---|
| `<catalog>.silver.aircraft_states` | `snapshot_hour_utc TIMESTAMP` (full UTC hour) | `snapshot_time BIGINT` source epoch seconds; `snapshot_at_utc`/`bucket_start_utc` UTC timestamps; `(snapshot_time, icao24)` key; optional callsign, source `origin_country`, position/contact timestamps, coordinates, nullable barometric/geometric altitude (metres), ground flag, speed (m/s), heading (degrees), vertical rate (m/s), squawk, SPI, position source, sensors; `bronze_path` provenance and `processed_at_utc` audit time. |
| `<catalog>.gold.aircraft_activity_5m` | `bucket_hour_utc TIMESTAMP` (full UTC hour) | `bucket_start_utc` five-minute UTC bucket, registration-country proxy (`Unknown` for null/blank), per-aircraft count, average latest within-bucket non-null barometric altitude (metres) and sample count, source epoch seconds (`last_source_time`) and refresh audit timestamp. |

Queries must use full UTC hour partition keys; the source's `time` is **BIGINT**, not an epoch-valued TIMESTAMP. No five-minute physical partition or one-hour batch delay. Silver's future stream overwrites complete affected hours only; the independent SQL task later atomically overwrites the complete Gold table. Live checkpoints are protected; 30-day Azure soft deletion is a recovery window, **not** an automatic expiry policy. Keep enough Bronze to reconstruct all retained Silver hours (initially ~30 days, at least trailing 24 hours after warm-up). A second source can reuse the same provisioned service only with a separate source prefix/volume, identities, UC grants and tested schema/jobs; never mix its files into the OpenSky root or share stream checkpoints.

## Backup, rollback, teardown and cost

Before each change, pause writers where a destructive change is possible and back up **both existing** state files and their matching plans in an encrypted, access-restricted location (before the first workspace apply, only Azure state exists). From the selected environment, set the correct `TF_DATA_DIR`, then run `terraform -chdir=infra/tf/azure state pull > "$STATE_ROOT/$ENV/azure.backup.tfstate"` and similarly `terraform -chdir=infra/tf/workspace state pull > "$STATE_ROOT/$ENV/workspace.backup.tfstate"`. Restrict permissions to the operator (`umask 077`, directory mode 700), keep dated off-machine encrypted copies, verify restore access, and do not commit backups. For rollback, stop writes, restore the matching state copy only after reconciling actual resources, regenerate/review plans, and reapply the previous pinned configuration; **state restoration does not restore deleted data**. Do not overwrite a newer state or restart a stream with a blank checkpoint.

`prevent_destroy` guards protect the storage account/containers, catalog, Bronze/checkpoint volumes and managed tables against accidental Terraform deletion. To decommission, first stop future collector/stream/SQL jobs, inventory and back up immutable Bronze, managed Silver/Gold data, checkpoints, Key Vault and both state files, and obtain explicit approval. Destroy `workspace/` before `azure/` only after reviewing resource dependencies and intentionally removing the relevant lifecycle guards in a temporary, reviewed configuration. With each root's own `TF_DATA_DIR` selected, re-run the matching plan command above with the same `-var-file` and required `-var` flags (including any later secret **names**), adding `-destroy` and using a fresh `-out="$STATE_ROOT/$ENV/workspace-destroy.tfplan"` (or `azure-destroy.tfplan`). Inspect each saved plan with `terraform show`, then apply that saved plan. Destroy `workspace/` first, then `azure/` **only after** the workspace is gone. `terraform destroy` against the checked-in guards should **fail** rather than erase data. Deleting a catalog/table/storage account can **irreversibly lose managed data and checkpoint progress** even after state backup; Key Vault purge protection and soft-delete retention may also delay name reuse. Verify bills and remaining Azure/Databricks objects after teardown.

No monthly bill or SKU price has been measured yet. Record actual `southeastasia` resource SKUs and billed hourly rates plus uptime after provisioning: AKS node+network, ACR, storage and requests, Log Analytics, Databricks classic Jobs VM+DBUs for continuous Silver (~730 hours/month if always on), Pro SQL warehouse DBUs+VM uptime, and data egress. Multiply *measured* rates by observed hours; do not infer a fixed total from schedules. At 120-second cadence expect ~720 Bronze files/day (~21,600/30 days) and 720 × four = 2,880 OpenSky states credits/day of a 4,000 daily limit; 1,120 credits/280 extra calls must cover **all** retries/manual polls across environments. Three simultaneously live environments need ~8,640 credits/day before retries, so don't enable them all against one account. Measure tiny-file overhead, full-hour Silver rereads/rewrites and full-Gold scans before changing design. A 100× observation volume differs from 100× source polling: the latter cannot use the same quota and compute budget. For shared/production operation, move local state to a locked, restricted ADLS Gen2 **AzureRM remote backend**, and validate private storage/Key Vault endpoints and DNS plus Databricks serverless SQL NCC separately; this PoC does not provision private access.
