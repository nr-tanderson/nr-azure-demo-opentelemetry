#!/usr/bin/env bash
set -euo pipefail
operation="$1"
connection=$(mktemp)
trap 'rm -f "$connection" "${connection}.next"' EXIT
blob="${TFSTATE_KEY}.connection.json"
publish() {
  az storage blob upload --account-name "$TFSTATE_STORAGE_ACCOUNT" --container-name "$TFSTATE_CONTAINER" --name "$blob" --file "$connection" --auth-mode login --overwrite true -o none
}
if [[ "$operation" == "destroy" ]]; then
  terraform -chdir=infra output -json lab_connection | jq '.state="paused"' > "$connection"
  publish
  resource_group=$(jq -r .resource_group "$connection")
  cluster=$(jq -r .cluster "$connection")
  az aks get-credentials --resource-group "$resource_group" --name "$cluster" --overwrite-existing
  kubelogin convert-kubeconfig -l azurecli
  if kubectl get namespace relibank-lab >/dev/null 2>&1; then
    kubectl patch cronjob payment-failure-window -n relibank-lab --type merge -p '{"spec":{"suspend":true}}'
    kubectl patch cronjob payment-traffic -n relibank-lab --type merge -p '{"spec":{"suspend":true}}'
    kubectl delete jobs -n relibank-lab -l lab-job=true --ignore-not-found
  fi
fi
terraform -chdir=infra apply -input=false lab.tfplan
if [[ "$operation" == "build" ]]; then
  bash scripts/tag-lab-resources.sh
  terraform -chdir=infra output -json lab_connection > "$connection"
else
  jq '.state="destroyed"' "$connection" > "${connection}.next"
  mv "${connection}.next" "$connection"
fi
publish
jq . "$connection" >> "$GITHUB_STEP_SUMMARY"