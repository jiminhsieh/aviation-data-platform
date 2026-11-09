# Proposal

## Why

The repository currently contains architecture notes and example OpenSky payloads, but no provisioned infrastructure or runnable ingestion/transformation code. A small, reproducible end-to-end slice is needed to demonstrate the take-home requirements: automated collection, replayable raw data, clean records, and self-service country-level analytics within minutes.

## What Changes

- Provision an Azure PoC foundation for AKS/ACR, ADLS Gen2, Key Vault and Databricks/Unity Catalog in `southeastasia`, with environment-isolated storage, identities, checkpoints and local Terraform state. Recommend an ADLS Gen2 AzureRM remote backend for shared/production deployments; it is not a PoC prerequisite.
- Add an OpenSky OAuth2 collector in the `ingestion` submodule, scheduled every two minutes on AKS, that archives immutable, source-shaped Snappy Avro responses directly to hourly UTC Bronze paths within the registered-account credit budget. No Kafka/Strimzi broker is required.
- Add **two independent** implementations in `transformation`: checkpointed Spark Structured Streaming that rebuilds complete affected Bronze hours into typed/deduplicated Silver, and separately scheduled SQL that atomically refreshes five-minute country-activity Gold from retained Silver. Silver and Gold use hourly UTC physical partitions.
- Complete the root and component READMEs with executable run/demo/teardown instructions, data contracts and governance, recovery procedures, measured cost/freshness and explicit PoC limitations. Reconcile remaining documentation drift rather than replacing already-aligned architecture sections. Include fixture-based contract, transformation and failure/replay checks.

## Capabilities

### New Capabilities
- `platform-foundation`: Reproducibly provision the Azure/Databricks environment, separately governed Bronze/checkpoint volumes and managed tables, with least-privilege access and a documented path to run it.
- `opensky-live-ingestion`: Periodically fetch the fixed-area feed using registered credentials and preserve original `time` and positional `states` in immutable, replayable Bronze Avro files.
- `bronze-silver-processing`: Produce typed, validated aircraft observations through deterministic complete-hour replacement, protected checkpoints and controlled replay independently of Gold.
- `country-activity-analytics`: Maintain self-service five-minute country activity and per-aircraft barometric-altitude metrics over at least the trailing 24 hours after warm-up, targeting measured p95 source-to-Gold freshness below five minutes.

### Modified Capabilities
- None (no existing main specs).

## Impact

- New Terraform under `infra/tf/` and collector Helm deployment assets; Python/image/schema code in the independent `ingestion` Git submodule; PySpark, SQL and version-controlled Job definitions in the independent `transformation` Git submodule; documentation in the root/component READMEs and architecture reference. The root repository must update its submodule pointers when implementation is committed.
- External prerequisites: an Azure subscription and permissions to create the listed resources, Databricks account administration for Unity Catalog setup, and a registered OpenSky OAuth2 client. No credentials, state, or live data belong in Git.
- AKS nodes, continuous Spark and frequent SQL warehouse refreshes dominate PoC cost; quote measured regional SKU/runtime costs rather than an unsupported monthly total. The runbook must cover safe shutdown and protected local state/data. CI/CD, multi-region HA, production private networking, generic connector frameworks and a polished UI remain out of scope.
