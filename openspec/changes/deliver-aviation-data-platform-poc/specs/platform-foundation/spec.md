# Spec Delta

## Purpose

Provide a repeatable, access-controlled Azure foundation on which the OpenSky scraper and data pipelines can run without undocumented cloud resources.

## ADDED Requirements

### Requirement: Provisionable connected environment
The platform SHALL declare the cloud storage, compute, streaming, secrets, catalog, and query resources and their connectivity as code, with independently named environments and repeatable deployment and teardown instructions.

#### Scenario: Deploy a new PoC environment
- **WHEN** an operator supplies an Azure subscription, required platform administration privileges, and the documented environment inputs
- **THEN** the declared infrastructure can be provisioned so the scraper can publish and the pipeline can read/write data and serve SQL without manually creating Azure resources

#### Scenario: Clean teardown
- **WHEN** an operator follows the documented destroy procedure
- **THEN** billable PoC resources are stopped or removed and the procedure warns about lake data and state deletion before irreversible actions

### Requirement: Separate workload and human access
The platform SHALL keep OpenSky and broker credentials out of version control and Terraform state, grant only the necessary workload access to secrets, streaming, and storage, and restrict raw/silver/gold reads and writes by persona.

#### Scenario: Data scientist explores the gold table
- **WHEN** a data scientist has read/query permissions but no platform-engineer role
- **THEN** they can run SQL against gold and read silver but cannot read raw, overwrite curated tables, or retrieve OpenSky credentials

#### Scenario: ATM expert inspects data
- **WHEN** an ATM domain expert is granted the documented analyst role
- **THEN** they can read silver and gold definitions and data without write access to curated or raw tables

#### Scenario: Pipelines run without embedded credentials
- **WHEN** the scraper and pipeline start from a fresh deployment
- **THEN** secrets are loaded at runtime through the documented secret delivery path and not stored in tracked files, Terraform variables/state, or application logs

### Requirement: Documented extension point
The repository SHALL document which shared platform resources and permissions a second source reuses and which source-specific topic, contract, collector, and table definitions it must add.

#### Scenario: Engineer plans another data source
- **WHEN** a platform engineer consults the architecture and infrastructure documentation
- **THEN** they can identify the reusable foundation and the source-specific steps without duplicating the whole platform
