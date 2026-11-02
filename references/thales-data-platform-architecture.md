# Data Platform Architecture

```mermaid
flowchart TB
    Teams[Developer and data teams]
    Git[Git repositories]
    CICD[CI/CD pipelines<br/>GitLab or equivalent]
    IaC[Terraform or OpenTofu]
    GitOps[GitOps<br/>FluxCD or Argo CD]
    SelfService[Self-service interfaces]

    Teams --> Git
    Teams --> SelfService
    Git --> CICD
    CICD --> IaC
    Git --> GitOps

    subgraph Azure[Azure cloud foundation]
        AKS[AKS / Kubernetes<br/>front-facing, data-oriented, and developer-oriented cluster profiles]
        ADLS[ADLS Gen2<br/>object storage]
        Entra[Entra ID]
        KeyVault[Key Vault]
        PrivateEndpoints[Private Endpoints]
    end

    IaC --> Azure
    GitOps --> AKS

    subgraph Platform[Data platform on Kubernetes]
        Kafka[Kafka / Strimzi<br/>event streaming]
        Airflow[Airflow<br/>orchestration]
        Lakehouse[Apache Iceberg<br/>lakehouse tables]
        Polaris[Polaris<br/>catalog and catalog-level access]
        Trino[Trino<br/>query engine]
        Spark[Spark]
        CloudNativePG[CloudNativePG<br/>managed databases]
        DataHub[DataHub<br/>cataloguing, lineage, and classification]
        Exploration[Grafana / Apache Superset<br/>Elasticsearch / Kibana]
    end

    AKS --> Platform
    Lakehouse --> ADLS
    Polaris --> Lakehouse
    Trino --> Lakehouse
    Spark --> Lakehouse
    Airflow --> Lakehouse
    DataHub --> Polaris
    Exploration --> Trino

    SelfService --> Kafka
    SelfService --> Lakehouse
    SelfService --> Polaris
    SelfService --> Airflow
    SelfService --> Trino
    SelfService --> AKS

    Entra --> AKS
    KeyVault --> AKS
    PrivateEndpoints --> AKS
    PrivateEndpoints --> ADLS
```

## Platform Controls

- Multi-tenancy and RBAC
- Least privilege, identity, secrets management, network segmentation, and supply-chain integrity
- Naming standards, access policies, retention, catalog RBAC, lineage, and classification
- FinOps controls
- SLIs and SLOs for availability and data freshness
- Drift detection and Git reconciliation
- Versioned, reviewed, tested, and secured infrastructure code
- Runbooks, incident response, root-cause analysis, and safe upgrades with no data loss

## Self-Service Capabilities

- Kafka topics, schemas, and credentials
- Iceberg tables and catalogs
- Airflow connections
- Kubernetes namespaces
- Query access
