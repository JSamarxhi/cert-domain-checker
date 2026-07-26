#!/usr/bin/env bash
# Creates the Azure Storage account that holds Terraform state, then prints
# the backend configuration to paste into terraform/backend.tf.
#
# Run once. These resources are deliberately NOT managed by Terraform: state
# cannot store the location of its own storage.

set -euo pipefail   # -e exit on error, -u error on undefined vars, -o pipefail catch errors in pipes

LOCATION="${LOCATION:-eastus}"
RG="rg-cert-checker-tfstate"

# Storage account names are globally unique across all of Azure, and must be
# 3-24 chars, lowercase letters and digits only. Append random hex to avoid
# collisions with anyone else's account.
SUFFIX=$(openssl rand -hex 3)
SA="stcertchecktf${SUFFIX}"

echo "Creating resource group ${RG}..."
az group create --name "$RG" --location "$LOCATION" --output none

echo "Creating storage account ${SA}..."
az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo "Creating blob container tfstate..."
az storage container create \
  --name tfstate \
  --account-name "$SA" \
  --auth-mode login \
  --output none

cat <<MSG

Done. Put these values in terraform/backend.tf:

  resource_group_name  = "${RG}"
  storage_account_name = "${SA}"
  container_name       = "tfstate"
  key                  = "cert-checker.tfstate"

Then migrate your existing local state into it:

  cd terraform
  terraform init -migrate-state

MSG
