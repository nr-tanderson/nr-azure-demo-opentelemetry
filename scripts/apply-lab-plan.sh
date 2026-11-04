#!/usr/bin/env bash
set -euo pipefail
operation="$1"
[[ "$operation" == build || "$operation" == destroy || "$operation" == finalize ]]
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
if [[ "$operation" != "finalize" ]]; then
  terraform -chdir=infra apply -input=false lab.tfplan
fi
if [[ "$operation" == "build" ]]; then
  terraform -chdir=infra output -json lab_connection | jq '.state="provisioned"' > "$connection"
elif [[ "$operation" == "finalize" ]]; then
  bash scripts/tag-lab-resources.sh
  terraform -chdir=infra output -json lab_connection > "$connection"
else
  jq '.state="destroyed"' "$connection" > "${connection}.next"
  mv "${connection}.next" "$connection"
fi
publish
jq . "$connection" >> "$GITHUB_STEP_SUMMARY"
if [[ "$operation" == "build" ]]; then
  principal_id="${TF_VAR_github_actions_principal_object_id:?Set the GitHub identity object ID}"
  node_group=$(az aks show --resource-group "$(jq -r .resource_group "$connection")" --name "$(jq -r .cluster "$connection")" --query nodeResourceGroup -o tsv)
  node_scope="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${node_group}"
  {
    printf '\n### Owner action before finalization\n\n'
    printf 'Using your Azure owner login, run these lab-scoped grants, then approve the lab-node-access deployment. No subscription-wide Contributor access is needed.\n\n'
    for role in Reader 'Tag Contributor'; do
      printf '    az role assignment create --assignee-object-id %q --assignee-principal-type ServicePrincipal --role %q --scope %q\n' "$principal_id" "$role" "$node_scope"
    done
  } >> "$GITHUB_STEP_SUMMARY"
fi