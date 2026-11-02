# Proposal

## Why

The repository currently contains architecture notes and example OpenSky payloads, but no provisioned infrastructure or runnable ingestion/transformation code. A small, reproducible end-to-end slice is needed to demonstrate the take-home requirements: automated collection, replayable raw data, clean records, and self-service country-level analytics within minutes.

## What Changes

- Provision an Azure PoC foundation for AKS/Strimzi Kafka, ADLS Gen2, Key Vault, and Databricks, with the identities, permissions, networking, and deployment instructions needed to connect them.
- Add an OpenSky OAuth2 scraper in the `ingestion` submodule, scheduled on AKS, that publishes versioned Avro poll records to Kafka within the registered-account credit budget.
- Add **two** implementations in `transformation`: Kafka Avro → durable raw + typed/deduplicated silver, and silver → hourly country-activity gold; expose gold to data scientists through Databricks SQL.
- Complete the root and component READMEs with an architecture diagram, executable run/demo/teardown instructions, data contract and governance, trade-offs, cost/freshness estimates, and explicit PoC limitations. Include focused tests using the supplied payload fixtures.

## Capabilities

### New Capabilities
- `platform-foundation`: Reproducibly provision the connected Azure/Kafka/Databricks environment with least-privilege access and a documented path to run it.
- `opensky-live-ingestion`: Periodically fetch the fixed-area feed using registered credentials and publish replayable Avro poll events.
- `bronze-silver-processing`: Archive the Avro Kafka events and produce typed, validated, idempotent aircraft observations.
- `country-activity-analytics`: Maintain queryable, fresh hourly aircraft activity and average altitude by origin country for at least the last 24 hours.

### Modified Capabilities
- None (no existing main specs).

## Impact

- New Terraform and deployment assets under `infra/tf/`; Python/image code in the independent `ingestion` Git submodule; PySpark code in the independent `transformation` Git submodule; documentation in each README and the root README. The root repository must update its submodule pointers when implementation is committed.
- External prerequisites: an Azure subscription and permissions to create the listed resources, Databricks account administration for Unity Catalog setup, and a registered OpenSky OAuth2 client. No credentials, state, or live data belong in Git.
- PoC infrastructure incurs always-on AKS/Kafka and streaming Databricks costs; the runbook must cover shutting it down. CI/CD, multi-region HA, private endpoints, and a polished UI remain out of scope.
