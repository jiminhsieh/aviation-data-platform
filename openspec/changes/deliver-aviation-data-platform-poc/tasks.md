# Tasks

## 1. Azure and Kafka foundation

- [ ] 1.1 Add pinned Terraform providers and parameterized `sit` Azure foundation in `infra/tf/` (resource group, VNet/NSGs, AKS/OIDC, ACR, ADLS Gen2 lake/checkpoints, Key Vault, Databricks workspace); verify `terraform fmt -check -recursive`, `terraform init`, `terraform validate`, and an operator-run `terraform plan` produce no undeclared infrastructure prerequisites.
- [ ] 1.2 Add Terraform-managed Strimzi Helm releases and repository-owned Kafka cluster/topic/user definitions (single persistent broker, private TLS listener, producer/consumer ACLs); verify rendered manifests, broker readiness, and authenticated access from both AKS and Databricks private subnets in a provisioned test environment.
- [ ] 1.3 Define Unity Catalog metastore assignment, storage access connector/locations, raw/silver/gold catalog grants, scoped job principal and auto-stopping SQL warehouse in Terraform; verify an authorized analyst can query silver/gold but not raw or secrets, and the job can write all layers without direct human ADLS access.
- [ ] 1.4 Add checked-in, non-logging deployment steps for injecting OpenSky credentials into Key Vault and synchronizing the Kafka consumer password/CA certificate into the Databricks secret scope, plus AKS workload identity/CSI mounts; verify no secret is present in tracked files or TF state and credential rotation is repeatable without application changes.
- [ ] 1.5 Replace `infra/tf/README.md` and add the root architecture/governance/cost sections (diagram, prerequisites, environment state, setup/teardown/rollback, role table, second-source reuse, $/month and 100× levers); verify every command points to a checked-in file and `terraform destroy` instructions warn about permanent data/checkpoint loss.

## 2. OpenSky scraper (`ingestion/` submodule)

- [ ] 2.1 Add a pinned Python CLI and v1 Avro poll schema with OAuth2 token exchange, fixed bounding box, full 17-field nullable vector validation, one states request/run and acknowledged Kafka publish; verify fixture-based tests for happy path, nullable fields, invalid payload, `429`, 5xx/timeout and redacted logs.
- [ ] 2.2 Add Docker packaging and an AKS CronJob deployment definition for `*/2` scheduling, `Forbid` overlap, bounded deadline, mounted secrets/CA and producer ACL; verify image builds, manifests render/validate, and a provisioned test run either produces one decodable event or fails without a second states request.
- [ ] 2.3 Update `ingestion/README.md` and the collection/freshness section of the root README with env inputs, run/observe commands and 720 × 4 = 2,880 credits/day vs the registered budget; verify documented commands and fixture examples match the CLI and Avro contract.

## 3. Kafka Avro → raw and silver (`transformation/` submodule)

- [ ] 3.1 Mirror the versioned schema, add the Kafka Structured Streaming reader with ADLS checkpoint and raw Delta MERGE keyed by topic/partition/offset (including exact Avro bytes and response/receipt times); verify local fixture tests preserve byte-for-byte values, deduplicate a repeated offset, and fail closed on an incompatible version.
- [ ] 3.2 Add typed vector expansion, coordinate/ID validation, null/callsign handling, rejected-row metrics and insert-only silver MERGE by response time + `icao24`; verify Spark fixture tests cover duplicate polls, bad coordinates, missing position, null altitude and deterministic batch retry without extra silver rows.
- [ ] 3.3 Update `transformation/README.md` and raw/silver sections of the root README with schema ownership, tables, replay/checkpoint behavior, data-quality definitions and why Delta date partitioning replaces minute overwrite; verify schema files agree with the documented field mapping and the root parity check (`cmp` or equivalent) passes.

## 4. Silver → gold and self-service (`transformation/` submodule)

- [ ] 4.1 Add a separate `silver_gold` implementation that recomputes affected UTC hour/origin-country buckets from silver and MERGEs distinct-aircraft count, non-null mean geo altitude, sample counts and latest response time into gold; verify Spark tests for repeated aircraft, null altitude, late hours, replay and unrelated buckets remaining unchanged.
- [ ] 4.2 Connect the two modules in a single one-minute-trigger streaming job that commits raw → silver → gold before checkpoint advancement; declare its pinned submodule revision, secrets/TLS options, compute and restart policy in checked-in Databricks deployment configuration; verify a forced gold failure and retry leave both upstream tables idempotent and eventually update gold.
- [ ] 4.3 Update the transformation and root READMEs with two entry points, SQL last-24-hours query, UTC/origin-country/altitude definitions, permissions and raw-versus-gold freshness checks; verify the query runs as an analyst and empty polls do not masquerade as failed ingestion.

## 5. Cross-repository acceptance

- [ ] 5.1 Commit ingestion and transformation changes in their own repositories, advance the root submodule pointers, and run both submodule test suites plus the root schema parity check; verify `git submodule update --init --recursive` restores precisely the documented implementation commits.
- [ ] 5.2 With operator-provided Azure/Databricks/OpenSky credentials, follow the documented provision → secrets → deploy → poll → raw/silver/gold SQL → teardown flow, checking actual latency (target <5 minutes from a successful poll), least-privilege denial and billable-resource cleanup; record observed results or explicitly mark live checks unverified if credentials are unavailable.
