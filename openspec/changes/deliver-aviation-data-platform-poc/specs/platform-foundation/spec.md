# Spec Delta

## Purpose

Provide a repeatable, access-controlled Azure foundation for direct-to-lake OpenSky collection, independently operated transformations and self-service SQL without undocumented cloud resources.

## ADDED Requirements

### Requirement: Provisionable isolated environments
The platform SHALL declare storage, compute, secrets, catalog, query resources and connectivity as code for independently named `sit`, `uat` and `prod` environments in `southeastasia`. Data, run identities, stream checkpoints and Terraform state SHALL be isolated per environment; deployment documentation SHALL identify bootstrap permissions, metastore availability and regional SKU/quota prerequisites without implying that all environments are running.

#### Scenario: Deploy a new PoC environment
- **WHEN** an operator supplies the documented Azure/Databricks bootstrap privileges and environment inputs
- **THEN** the declared resources support AKS collection into Bronze, checkpointed Silver processing and independently scheduled SQL Gold without manually creating undocumented infrastructure

#### Scenario: Select another environment
- **WHEN** an operator deploys a second environment using the reusable configuration
- **THEN** it cannot accidentally reuse the first environment's state, source data, run identities or checkpoint path

### Requirement: Governed storage and independent execution
The platform SHALL provide ADLS Gen2 `bronze`, `lakehouse` and `quarantine` containers in one storage account with blob soft delete disabled, and a `checkpoints` container in a separate account with 30-day blob soft delete. It SHALL provide separately governed Bronze/checkpoint volumes and managed Silver/Gold Delta tables. Bronze paths and table partitions SHALL use full UTC source hours. Checkpoints SHALL be outside source discovery and table storage, protected from automatic expiry; soft delete is a recovery window, not expiry. Silver and Gold SHALL have independent execution, retry and single-writer controls.

#### Scenario: Bootstrap the lakehouse
- **WHEN** an environment is prepared for its first pipeline run
- **THEN** the canonical Bronze directory and protected checkpoint location exist in their respective storage accounts, only the checkpoint account has 30-day blob soft delete, Silver is partitioned by `snapshot_hour_utc`, and Gold is partitioned by `bucket_hour_utc` without granting analysts underlying storage access

#### Scenario: Gold execution is unavailable
- **WHEN** Gold SQL execution fails or is paused
- **THEN** Silver can continue committing observations with its own checkpoint while the prior committed Gold remains queryable

### Requirement: PoC state and safe teardown
The PoC SHALL use Terraform's local backend to keep setup simple, with separately protected and backed-up state per environment. State and secret-bearing variable files SHALL never be committed. Documentation SHALL recommend an ADLS Gen2 storage account with Terraform's AzureRM remote backend, restricted access and locking for shared/production deployments, without requiring it for the PoC.

#### Scenario: Prepare PoC Terraform state
- **WHEN** an operator follows the PoC setup instructions
- **THEN** local state is isolated by environment, excluded from Git and covered by protection/backup guidance without provisioning a remote backend

#### Scenario: Clean teardown
- **WHEN** an operator follows the documented destroy procedure
- **THEN** billable resources are stopped or removed, needed local state/data are preserved, and warnings precede irreversible lake, managed-table or checkpoint deletion; the lack of blob soft delete on Bronze, lakehouse and quarantine is explicit

### Requirement: Separate workload and human access
The platform SHALL use distinct least-privilege collector, Silver-stream and Gold-SQL identities without static Azure storage keys. OpenSky registration and secret injection SHALL be documented external inputs, with secret values excluded from tracked files, Terraform variables/state and logs. The collector SHALL access only its OpenSky secrets, Bronze creation/collision reads and quarantine writes; the stream SHALL read Bronze, read/write its checkpoint and read/modify Silver; Gold SQL SHALL read Silver, read/modify Gold and use its warehouse.

#### Scenario: Data scientist explores curated data
- **WHEN** a data scientist has read/query permissions but no platform-engineer role
- **THEN** they can query Silver/Gold but cannot read Bronze/checkpoints, overwrite curated tables or retrieve OpenSky credentials

#### Scenario: ATM expert inspects data
- **WHEN** an ATM expert receives the documented analyst role
- **THEN** they can read Gold definitions/data and optionally Silver if explicitly granted, with no Bronze/checkpoint/secret or curated-write access

#### Scenario: Workloads start without embedded credentials
- **WHEN** the collector, stream and SQL task start from a fresh deployment
- **THEN** the collector receives mounted OpenSky secrets through Workload Identity/Key Vault CSI, Databricks storage access uses the Access Connector and catalog grants, and each workload is denied the other workloads' unnecessary privileges

### Requirement: Explicit networking boundary
The PoC SHALL use authenticated HTTPS service access with anonymous storage access disabled and documented public-endpoint justification. Production guidance SHALL cover private storage/Key Vault connectivity and DNS, including the separate supported serverless SQL networking workflow, without claiming an unverified all-private deployment.

#### Scenario: Verify runtime connectivity
- **WHEN** an operator validates the PoC network and access configuration
- **THEN** AKS can reach its authorized Key Vault/ADLS resources and Databricks can reach ADLS while unauthenticated data access is denied

### Requirement: Documented extension point
The repository SHALL identify the foundation a second source reuses and its required adapter, credentials, source schema/path, dedicated checkpoint, Silver keys and Gold semantics without requiring a generic connector framework.

#### Scenario: Engineer plans another source
- **WHEN** a platform engineer consults the architecture and infrastructure documentation
- **THEN** they can distinguish reusable Azure/AKS/storage/catalog/SQL resources from source-specific contracts and transformations without duplicating the whole platform
