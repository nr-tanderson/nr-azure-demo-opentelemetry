#!/usr/bin/env bash
set -euo pipefail

: "${STATE_STORAGE_ACCOUNT:?Set STATE_STORAGE_ACCOUNT to a globally unique lowercase name}"
STATE_RESOURCE_GROUP="${STATE_RESOURCE_GROUP:-rg-nr-aks-demo-state}"
STATE_LOCATION="${STATE_LOCATION:-eastus}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"

az group create \
  --name "$STATE_RESOURCE_GROUP" \
  --location "$STATE_LOCATION" \
  --tags OWNER=TANDERSON PROJECT=nr-azure-demo-opentelemetry MANAGED_BY=Terraform \
  --output none

az storage account create \
  --name "$STATE_STORAGE_ACCOUNT" \
  --resource-group "$STATE_RESOURCE_GROUP" \
  --location "$STATE_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags OWNER=TANDERSON PROJECT=nr-azure-demo-opentelemetry MANAGED_BY=Terraform \
  --output none

az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

printf 'Terraform state backend ready: resource group=%s storage account=%s container=%s\n' \
  "$STATE_RESOURCE_GROUP" "$STATE_STORAGE_ACCOUNT" "$STATE_CONTAINER"