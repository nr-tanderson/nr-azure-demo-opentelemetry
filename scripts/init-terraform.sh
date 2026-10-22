#!/usr/bin/env bash
set -euo pipefail

: "${TFSTATE_RESOURCE_GROUP:?Set the GitHub variable TFSTATE_RESOURCE_GROUP}"
: "${TFSTATE_STORAGE_ACCOUNT:?Set the GitHub variable TFSTATE_STORAGE_ACCOUNT}"
: "${TFSTATE_CONTAINER:?Set the GitHub variable TFSTATE_CONTAINER}"
: "${TFSTATE_KEY:?Set the GitHub variable TFSTATE_KEY}"
: "${AZURE_CLIENT_ID:?Set the AZURE_CLIENT_ID secret}"
: "${AZURE_TENANT_ID:?Set the AZURE_TENANT_ID secret}"
: "${AZURE_SUBSCRIPTION_ID:?Set the AZURE_SUBSCRIPTION_ID secret}"

terraform -chdir=infra init -input=false \
  -backend-config="resource_group_name=${TFSTATE_RESOURCE_GROUP}" \
  -backend-config="storage_account_name=${TFSTATE_STORAGE_ACCOUNT}" \
  -backend-config="container_name=${TFSTATE_CONTAINER}" \
  -backend-config="key=${TFSTATE_KEY}" \
  -backend-config="use_oidc=true" \
  -backend-config="use_azuread_auth=true" \
  -backend-config="client_id=${AZURE_CLIENT_ID}" \
  -backend-config="tenant_id=${AZURE_TENANT_ID}" \
  -backend-config="subscription_id=${AZURE_SUBSCRIPTION_ID}"