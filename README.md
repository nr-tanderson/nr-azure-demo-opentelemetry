# AKS OpenTelemetry Astronomy Shop

For the separate ReliBank payment-code-fix workshop, start with [LAB-OPERATIONS.md](LAB-OPERATIONS.md). That lab adds saved-plan approval gates, a generation handoff and a persistent registry; its app workflows and walkthrough live in your separate ReliBank repo. The older Astronomy Shop instructions below do not describe that new lab's image lifecycle.

Manually operated GitHub Actions workflows create and destroy an Azure Kubernetes Service cluster and can deploy the upstream OpenTelemetry Astronomy Shop. New Relic is optional and disabled by default; it can be enabled later with a new lab-only key.

The app is not copied or rebuilt in this repository. The deployment workflow installs the official [OpenTelemetry Demo Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-demo), pinned to chart `0.42.6` / app `3.1.0`. The chart pulls the community's published images. Source and issue tracking remain in the [upstream application repository](https://github.com/open-telemetry/opentelemetry-demo).

## Workflows

- **Build AKS infrastructure** applies `infra/` and creates one AKS cluster in a dedicated resource group. No ACR is needed because the upstream images are published by the project.
- **Deploy OpenTelemetry Astronomy Shop** installs the pinned upstream chart and smoke-tests the frontend. Its `enable_monitoring` input defaults to false, so no New Relic key is read or telemetry secret created unless explicitly opted in.
- **Destroy AKS infrastructure** requires typing `DESTROY-NR-AKS-DEMO`, then destroys the Terraform-managed demo resources. Terraform state storage and telemetry already ingested by New Relic are not destroyed.

All three workflows require manual dispatch. The Astronomy Shop workflow exposes only its frontend through a tagged Azure LoadBalancer and prints the temporary public URL in the Actions summary. Databases and internal services stay cluster-internal. Anyone who knows the frontend IP can reach this demo, so uninstall the app when the lab is not in use. With monitoring off, the upstream chart uses its bundled demo observability components. New Relic application telemetry is a later, explicit opt-in; this app workflow does not install a persistent cluster-wide New Relic agent.

## Capacity and cost

The official Kubernetes guide lists about 6 GB of free RAM for the demo. The Terraform default is one `Standard_D4as_v5` node (16 GiB), which is intentionally larger than the previous custom sample and will cost more. It is still a single-node, non-HA test cluster; it can be unavailable during node or platform maintenance. Verify VM availability and pricing in the selected Azure region before building. The load generator is reduced to two users and browser traffic is disabled.

## Prerequisites

- Azure CLI, Terraform 1.9.8+, and a GitHub repository containing this project.
- A GitHub Actions OIDC application/service principal with a federated credential restricted to this repository. Grant it permission to create the demo resource group/AKS cluster and role assignments, plus `Storage Blob Data Contributor` on the Terraform state account. No client secret is used.
- No New Relic key is required for the default lab setup.

The cluster disables local AKS accounts and enables Azure RBAC. Terraform grants the GitHub OIDC identity the `Azure Kubernetes Service RBAC Cluster Admin` role on this demo cluster so deployment does not use `--admin` kubeconfig credentials.

Terraform applies `OWNER=TANDERSON`, `PROJECT=nr-azure-demo-opentelemetry`, and `MANAGED_BY=Terraform` to the demo resource group, AKS cluster, and node pool. The state bootstrap script applies the same tags to the separate state resource group and storage account. Azure role assignments do not support tags. AKS also creates a managed node resource group and child resources; the AzureRM provider does not expose a tag argument for the managed resource group itself, so organization-wide tag inheritance would require an Azure Policy assignment.

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
New Relic remains unconfigured until you are ready. Later, add a fresh `LAB_NR_LICENSE_KEY` Actions secret and explicitly check `enable_monitoring` in the app workflow. Do not reuse or paste an existing key. `NEW_RELIC_OTLP_ENDPOINT` can select the ingest region (`https://otlp.nr-data.net` for US or `https://otlp.eu01.nr-data.net` for EU).

The OIDC federated credential must match the repository and branch/environment used by GitHub Actions. Do not store Azure credentials or the New Relic license key in this repository.

The chart docs say upgrades between chart versions are unsupported. The workflow pins `0.42.6`; to move to a different chart version, uninstall the Helm release first and then rerun deployment.