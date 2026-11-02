# Aviation Data Platform

## Architecture Diagram

## Architecture Decision

### Repository
The requirements initially suggest a monorepo. However, a monorepo may complicate team access control and CI/CD because every team must work within the same repository. At the same time, it provides valuable organization-wide visibility into the codebase.

To balance these trade-offs, I propose a polyrepo structure connected through Git submodules. Each team can independently manage its repository, permissions, and CI/CD pipelines, while a top-level repository provides a unified view of the overall system.

* Infrastructure code - [infra/tf](infra/tf)
* Ingestion code - [ingestion](https://github.com/jiminhsieh/aviation-data-scraper)
* Transformation code - [transformation](https://github.com/jiminhsieh/aviation-data-pipeline)

### Data Platform

1. The response from opensky-network will be converted from JSON to Avro format and publish to Kafka.
   1. Avro is a better format in raw zone because of its fast row-based read performance, low storage overhead, and robust support for schema evolution.
2. We have 2 containers. One is for raw zone and another is for cleansed zone.
3. Use Databricks for pipeline transformation as it takes care of data governance, data lineage, and auditing at least.
4. Use Spark streaming to read Kafka Avro record then sa
5. Use AKS for data ingestion job. I chose AKS because we could also consider to run some Spark jobs on k8s for cost reduction.
6. Don't need to use any private endpoint as I assume we don't need to build an intranet. 
   1. If we need to set up data lake in isolated network, we will need some resources like private endpoints and private DNS

### Data Lake
1. Use minutely partitioning as the requirement is user expect data latency less than a few minutes.
2. Data Access Permission Table

| Components | ATM | Data Scientist | Platform Engineer |
|---|---|---|---|
| Raw Zone| None | None | READ only or RW | 
| Silver Zone | Read Only | Read only | RW |
| Gold Zone | Read Only | RW | RW |
| Key Vault | None | Key Vault Reader | Key Vault Administrator |

## Runbook  

