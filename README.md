# AKS OpenTelemetry Astronomy Shop

Manually operated GitHub Actions workflows create an Azure Kubernetes Service cluster, deploy the upstream OpenTelemetry Astronomy Shop, send application telemetry to New Relic, and destroy the demo cluster separately.

The app is not copied or rebuilt in this repository. The deployment workflow installs the official [OpenTelemetry Demo Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-demo), pinned to chart `0.42.6` / app `3.1.0`. The chart pulls the community's published images. Source and issue tracking remain in the [upstream application repository](https://github.com/open-telemetry/opentelemetry-demo).

## Workflows

- **Build AKS infrastructure** applies `infra/` and creates one AKS cluster in a dedicated resource group. No ACR is needed because the upstream images are published by the project.
- **Deploy OpenTelemetry Astronomy Shop** installs New Relic Kubernetes monitoring and the pinned upstream chart, configures the OpenTelemetry Collector to export traces, metrics, and logs to New Relic, waits for Helm readiness, then smoke-tests the frontend through a temporary port-forward.
- **Destroy AKS infrastructure** requires typing `DESTROY-NR-AKS-DEMO`, then destroys the Terraform-managed demo resources. Terraform state storage and telemetry already ingested by New Relic are not destroyed.

All three workflows require manual dispatch. The demo frontend is not exposed with a public load balancer; access it with `kubectl port-forward` after deployment:

```sh
kubectl port-forward -n otel-demo svc/frontend-proxy 8080:8080
```

Then open `http://localhost:8080`. The upstream chart also offers its own Grafana/Jaeger interfaces; this configuration disables bundled Grafana, Prometheus, Jaeger, and OpenSearch to limit duplicate telemetry and resource use. New Relic receives the application's traces, metrics, and logs, and the New Relic bundle receives AKS infrastructure and Kubernetes event telemetry.

## Capacity and cost

The official Kubernetes guide lists about 6 GB of free RAM for the demo. The Terraform default is one `Standard_D4as_v5` node (16 GiB), which is intentionally larger than the previous custom sample and will cost more. It is still a single-node, non-HA test cluster; it can be unavailable during node or platform maintenance. Verify VM availability and pricing in the selected Azure region before building. The load generator is reduced to two users and browser traffic is disabled.

## Prerequisites

- Azure CLI, Terraform 1.9.8+, and a GitHub repository containing this project.
- A GitHub Actions OIDC application/service principal with a federated credential restricted to this repository. Grant it permission to create the demo resource group/AKS cluster and role assignments, plus `Storage Blob Data Contributor` on the Terraform state account. No client secret is used.
- A New Relic ingest license key in the GitHub Actions secret `NEW_RELIC_LICENSE_KEY`.

The cluster disables local AKS accounts and enables Azure RBAC. Terraform grants the GitHub OIDC identity the `Azure Kubernetes Service RBAC Cluster Admin` role on this demo cluster so deployment does not use `--admin` kubeconfig credentials.

Terraform applies `OWNER=TANDERSON`, `PROJECT=nr-azure-demo-opentelemetry`, and `MANAGED_BY=Terraform` to the demo resource group, AKS cluster, and node pool. The state bootstrap script applies the same tags to the separate state resource group and storage account. Azure role assignments do not support tags. AKS also creates a managed node resource group and child resources; the AzureRM provider does not expose a tag argument for the managed resource group itself, so organization-wide tag inheritance would require an Azure Policy assignment.

## Terraform state setup

After `az login`, select the intended subscription and bootstrap a separate state account. Use a globally unique lowercase storage account name:

```sh
STATE_STORAGE_ACCOUNT=nraksstateYOURUNIQUEID \
STATE_RESOURCE_GROUP=rg-nr-aks-demo-state \
bash scripts/bootstrap-state.sh
```

Keep the state account outside the demo teardown. Configure these GitHub **Actions secrets**:

- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` for OIDC login.
- `NEW_RELIC_LICENSE_KEY` for New Relic ingest.

Configure these GitHub **Actions variables**:

- `AZURE_CLIENT_OBJECT_ID`: service principal object ID for the cluster-scoped Azure RBAC assignment.
- `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`, and `TFSTATE_KEY` for the remote backend.
- `NEW_RELIC_OTLP_ENDPOINT`: optional; defaults to `https://otlp.nr-data.net`. Set `https://otlp.eu01.nr-data.net` for the EU data region.

The OIDC federated credential must match the repository and branch/environment used by GitHub Actions. Do not store Azure credentials or the New Relic license key in this repository.

The chart docs say upgrades between chart versions are unsupported. The workflow pins `0.42.6`; to move to a different chart version, uninstall the Helm release first and then rerun deployment.