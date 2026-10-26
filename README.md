# Shared AKS Demo Infrastructure

This repository manages only the shared Azure Kubernetes Service lab cluster, its persistent Terraform state/artifact storage, reviewed build/destroy plans, generation handoff, locking, and Azure resource tags. **Application deployment workflows live in their own app repositories**, not here:

- [ReliBank](https://github.com/nr-tanderson/relibank): synthetic payment timeout code-fix lab.
- [OpenTelemetry Astronomy Shop](https://github.com/nr-tanderson/opentelemetry-demo): official upstream demo fork.
- [Spring PetClinic Microservices](https://github.com/nr-tanderson/spring-petclinic-microservices): official Spring PetClinic fork.

Each app repo has a manual deploy/uninstall workflow that reads the active cluster handoff and shares this repo's Azure Blob operation lock. Deploy one app at a time on the single-node demo cluster.

## Workflows

The **Build AKS infrastructure** workflow creates the cluster only after plan review and the `lab-infrastructure` approval. **Destroy AKS infrastructure** requires typed confirmation, a reviewed destroy plan, and the same approval. The persistent registry and state account remain after cluster teardown.

## Capacity and cost

The Terraform default is one `Standard_D4as_v5` node (16 GiB), suitable for one demo app at a time but non-HA. Verify VM availability and regional price before building. The persistent state storage and ACR remain billable after cluster teardown.

## Prerequisites

- Azure CLI, Terraform 1.9.8+, and a GitHub repository containing this project.
- A GitHub Actions OIDC application/service principal with a federated credential restricted to this repository. Grant it permission to create the demo resource group/AKS cluster and role assignments, plus `Storage Blob Data Contributor` on the Terraform state account. No client secret is used.
- No New Relic key is required for infra provisioning or the default ReliBank/OTel deployments.

The cluster disables local AKS accounts and enables Azure RBAC. Terraform grants the GitHub OIDC identity the `Azure Kubernetes Service RBAC Cluster Admin` role on this demo cluster so deployment does not use `--admin` kubeconfig credentials.

Terraform applies `OWNER=TANDERSON`, `PROJECT=nr-azure-demo-opentelemetry`, and `MANAGED_BY=Terraform` to the demo resource group, AKS cluster, and node pool. The state bootstrap script applies the same tags to the separate state resource group, storage account, and ACR. The reviewed build workflow also tags supported AKS-managed resources in the node resource group. Azure role assignments do not support tags; Azure Policy is required for inheritance beyond resources that support tags.

## Terraform state setup

After `az login`, select the intended subscription and bootstrap a separate state account. Use a globally unique lowercase storage account name:

```sh
STATE_STORAGE_ACCOUNT=nraksstateYOURUNIQUEID \
STATE_RESOURCE_GROUP=rg-nr-aks-demo-state \
bash scripts/bootstrap-state.sh
```

Keep the state account outside the demo teardown. Configure these GitHub **Actions secrets** for Azure:

- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` for OIDC login.

Configure these GitHub **Actions variables**:

- `AZURE_CLIENT_OBJECT_ID`: service principal object ID for the cluster-scoped Azure RBAC assignment.
- `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`, and `TFSTATE_KEY` for the remote backend.
The OIDC federated credential must match the repository and branch/environment used by GitHub Actions. Do not store Azure credentials or the New Relic license key in this repository.