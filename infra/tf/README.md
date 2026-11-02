# Data Platform Infra

## Architecture Design Decision
1. Store TF state locally because it's a PoC. We should ADLS in real delivery.
2. 3 environments on Azure southeastasia: sit, uat, and prod 
3. Below components are the confirmed tech stacks
   1. Azure cloud in southeastasia area
   2. AKS
   3. ADLS Gen2
   4. Azure Key Vault
   5. Azure Databricks
   6. Kafka with Strimzi
