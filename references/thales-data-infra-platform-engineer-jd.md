# [Data Infra Platform Engineer](https://careers.thalesgroup.com/global/en/job/R0333615/Data-Infra-Platform-Engineer)

- **Location:** Singapore, Singapore
- **Job ID:** R0333615
- **Employment type:** Full time
- **Category:** Software
- **Work location:** Singapore

Thales is a global technology leader trusted by governments, institutions, and enterprises to tackle their most demanding challenges. From quantum applications and artificial intelligence to cybersecurity and 6G innovation, our solutions empower critical decisions rooted in human intelligence. Operating at the forefront of aerospace and space, cybersecurity and digital identity, we’re driven by a mission to build a future we can all trust.

In Singapore, Thales has been a trusted partner since 1973, originally focused on aerospace activities in the Asia-Pacific region. With 2,000 employees across three local sites, we deliver cutting-edge solutions across aerospace (including air traffic management), defence and security, and digital identity and cybersecurity sectors. Together, we’re shaping the future by enabling customers to make pivotal decisions that safeguard communities and power progress.

## Responsibilities

### Cloud infrastructure as code

- Build the cloud foundation in Terraform, to a high standard and designed to be configurable, so the platform can provision clusters of different profiles (front-facing, data-oriented, developer-oriented) from the same well-factored code.
- You treat infrastructure as code as software: small, composable modules with the versioning, review, and testing that make them reliable and reusable. The desired state lives in Git, the platform reconciles to it through GitOps, and drift is detected rather than discovered.

### Data platform engineering on Kubernetes

- Build and operate the infrastructure that runs the data platform: a lakehouse on Apache Iceberg with a Polaris catalog and Trino, event streaming on Kafka, orchestration with Airflow, and managed databases such as CloudNativePG, all on object storage (ADLS Gen2). Your focus is on the platform beneath these systems: deploying, securing, scaling, and upgrading them as first-class capabilities, with the multi-tenancy, RBAC, governance, and FinOps that keep a shared platform healthy.
- Deep expertise in how data is modelled or processed is not required. A working understanding of how these systems are used is highly desirable, but the core of the job is keeping the infrastructure reliable, secure, and available.

### Data governance and metadata

- Operate the catalog and metadata layer that makes data discoverable and governed for cataloguing, lineage, and classification, and Polaris for catalog-level access. You enforce the conventions and controls that keep data well managed, such as naming standards, access policies, and retention. This is infrastructure and policy work: you run the tooling and the guardrails, without owning the meaning of the data.

### Data self-service

- Build the interfaces that let teams' provision what they need, such as Kafka topics and credentials, Iceberg tables and catalogs, Airflow connections, namespaces, and query access, without the platform team becoming a bottleneck. The goal is a platform that scales through self-service rather than manual requests, with capabilities maturing toward self-served or provided by default. You document these paths as you build them, so runbooks and guides are part of the deliverable.

### Operate and keep it reliable

- Own the data platform at runtime, not just at provisioning. You define and measure the SLIs and SLOs, including data freshness and availability, write the runbooks that make failure recoverable, and lead incident response when the platform degrades or data stops flowing. You run lifecycle work such as cluster, broker, and engine upgrades with no data loss and minimal disruption, and trace failures to root cause.

## Requirements

### Education

- Bachelor's degree in computer science, Information Technology or related field.
- Masters degree in Computer Science or Information Technology if applicable.

### Essential Skills/Experience

- Several years building platform or data-platform capabilities end to end, production-grade, self-service solutions (three to five years is a useful guide).
- Strong, hands-on production of Kubernetes, including operating stateful, distributed systems (databases, brokers, query engines) and resolving issues under pressure.
- Hands-on experience operating at least one core data system (Kafka, Iceberg/Trino/Spark, or Airflow) as a platform service.
- Experience running data exploration and visualization tooling such as Grafana, Apache Superset, Elasticsearch, and Kibana.
- Solid infrastructure-as-code (Terraform or OpenTofu) and GitOps delivery (FluxCD or Argo CD).
- A working command of CI/CD pipelines and release strategy (GitLab, or equivalent).
- A sound grasp of cloud-native security: least privilege, network segmentation, secrets management, identity, and supply-chain integrity.
- Operational maturity: defining SLOs, incident response, and safe upgrades with no data loss.
- Proficiency in Python and one of Go or Bash, and comfort on Linux.
- The conviction that infrastructure is code: version-controlled, reviewed, tested, and secured.

### Desirable Skills/Experience

- Working knowledge of SQL and data modelling. Valued but not required; the role centres on the infrastructure, not the data itself.
- Depth in Azure services (AKS, ADLS Gen2, AI Foundry, Key Vault, Entra ID, Private Endpoints).
- Kafka and Strimzi, including topics, schema, and credential management.
- Lakehouse and query engines: Iceberg, Polaris, Trino, and Spark on object storage.
- Airflow, including providers and connection management.
- Metadata and governance: DataHub, lineage, classification, and catalog RBAC.
- Managed databases on Kubernetes (CloudNativePG or similar).
- Building or operating an internal developer or data platform.

### Essential / Desirable Traits

- You see systems end to end and resist thinking in silos.
- You treat the platform as a product: you measure adoption and let evidence, not assumption, guide what to build, harden, or retire.
- You have learning agility, flexibility, and initiative.
- You are comfortable in an agile team, engaging directly with the developers you serve.
- You hold your convictions with humility, welcome feedback, and stay resilient.

At Thales, we’re committed to fostering a workplace where respect, trust, collaboration, and passion drive everything we do. Here, you’ll feel empowered to bring your best self, thrive in a supportive culture, and love the work you do. Join us, and be part of a team reimagining technology to create solutions that truly make a difference – for a safer, greener, and more inclusive world.
