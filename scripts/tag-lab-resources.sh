#!/usr/bin/env bash
set -euo pipefail
resource_group=$(terraform -chdir=infra output -raw resource_group_name)
cluster=$(terraform -chdir=infra output -raw cluster_name)
node_group=$(az aks show --resource-group "$resource_group" --name "$cluster" --query nodeResourceGroup -o tsv)
test -n "$node_group"
node_group_id=$(az group show --name "$node_group" --query id -o tsv)
tags=(OWNER=TANDERSON PROJECT=nr-azure-demo-opentelemetry MANAGED_BY=Terraform)
az tag update --resource-id "$node_group_id" --operation Merge --tags "${tags[@]}" -o none
resources=$(az resource list --resource-group "$node_group" -o json)
while IFS= read -r resource_id; do
  az tag update --resource-id "$resource_id" --operation Merge --tags "${tags[@]}" -o none
done < <(jq -r '.[] | select((.type | ascii_downcase) as $type | ["microsoft.compute/virtualmachinescalesets", "microsoft.compute/disks", "microsoft.managedidentity/userassignedidentities", "microsoft.network/virtualnetworks", "microsoft.network/networksecuritygroups", "microsoft.network/publicipaddresses", "microsoft.network/loadbalancers", "microsoft.network/networkinterfaces"] | index($type)) | .id' <<< "$resources")
printf 'Tagged supported AKS-managed resources in %s with OWNER=TANDERSON.\n' "$node_group"