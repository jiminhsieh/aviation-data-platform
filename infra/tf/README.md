# Data Platform Infra

**Status: Adopted design / implementation pending.** This directory does not yet contain checked-in Terraform configuration or runnable deployment commands. The [architecture and technical design](../../references/thales-azure-data-platform-design.md) is authoritative for the target platform.

## Architecture Design Decision

- **Environments:** `sit`, `uat`, `prod`.
- **Azure region:** `southeastasia` (Southeast Asia) for all three environments.
- Reuse Terraform code with environment-specific inputs; isolate state, data, run identities and stream checkpoints between environments.
- The pipeline is AKS ingestion → ADLS Bronze → Databricks streaming Silver → independently scheduled SQL Gold. No Kafka/Strimzi broker is required.

## Provisioning Scope

| Area | Planned resources / configuration |
|---|---|
| Foundation/network | Resource group, VNet/subnets and NSGs |
| Storage | ADLS Gen2 with hierarchical namespace; `bronze`, `checkpoints`, `lakehouse` and `quarantine` containers; scoped retention |
| AKS/ACR | Minimal node pool, registry pull access, OIDC/Workload Identity and collector CronJob every 120 seconds |
| Identity/Key Vault | Managed identities, federation, scoped RBAC, Key Vault and Secrets Store CSI configuration |
| Databricks | Workspace, Access Connector, metastore assignment where required, UC catalog/schemas, volumes, grants and managed Delta tables |
| Compute/jobs | Continuous Silver Job on classic Jobs compute; independent Gold SQL-file task every two minutes on a Pro or Serverless SQL warehouse |
| Monitoring | Log Analytics/diagnostics, practical alerts and retention |

**Delivery boundaries:** AzureRM provisions Azure resources; the Databricks provider configures workspace/Unity Catalog objects after workspace availability; Helm deploys the collector. Keep infrastructure reproducible rather than relying on undocumented portal-created resources.

Bronze uses source-time hourly UTC paths. Bootstrap Silver partitioned by `snapshot_hour_utc` and Gold by `bucket_hour_utc`. Govern Bronze and checkpoints through separate UC volumes; keep live checkpoints protected from automatic expiry.

## State and Access

- Use a restricted remote backend with locking for shared deployments and separate state per environment. Never commit Terraform state or secret-bearing variable files.
- Register the external OpenSky API client and inject its credentials into Key Vault outside Terraform state. These are documented manual inputs, not Terraform-managed secret values.
- Use separate collector, Silver stream and Gold SQL identities. The collector uses AKS Workload Identity and Key Vault CSI; Databricks storage access uses the Access Connector and UC grants, not user storage keys.
- Analysts have no Bronze, checkpoint or Key Vault access. Data scientists read Silver/Gold; ATM users read Gold and optionally Silver. See the [full access matrix](../../references/thales-azure-data-platform-design.md#102-access-matrix).

## Networking

For this PoC, use authenticated public Azure service endpoints over HTTPS, disable anonymous storage access and verify AKS→Key Vault/ADLS and Databricks→ADLS connectivity. This is a deliberate scope/cost trade-off, not public access to the data.

Private endpoints and associated private DNS are deferred for the PoC. Production hardening includes private storage/Key Vault connectivity; For private storage access, Databricks serverless SQL uses its supported NCC/private-endpoint workflow, separate from the AKS VNet. Validate connectivity before restricting public storage access; do not claim an all-private deployment.

## Planned Setup and Validation

No executable setup commands are supplied until the Terraform configuration and deployment artifacts exist. The intended order is:

1. Select `sit`, `uat` or `prod`; confirm Azure/Databricks bootstrap permissions, metastore availability, and required SKU availability/quotas in `southeastasia`.
2. Prepare the environment's remote backend and provision Azure foundation, storage, AKS/ACR, identities, Key Vault and Databricks resources.
3. Configure UC volumes, managed tables, grants, compute and jobs. Bootstrap the Bronze source directory before starting the explicit-schema stream.
4. Securely inject OpenSky credentials, build/push the collector image and deploy its ServiceAccount/CSI/CronJob through Helm.
5. Start the checkpointed Silver stream, then enable the independent Gold SQL task with its UTC schedule. Enforce one active writer per target.
6. Verify hourly layouts, analyst permissions, failure/replay behavior and measured freshness/cost.

Detailed planned procedures:

- [First-run checklist](../../references/thales-azure-data-platform-design.md#first-run-checklist)
- [Test strategy and acceptance](../../references/thales-azure-data-platform-design.md#16-test-strategy-and-acceptance)
- [Replay and recovery](../../references/thales-azure-data-platform-design.md#93-replay-runbook)