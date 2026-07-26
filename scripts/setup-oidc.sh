#!/usr/bin/env bash
# Sets up passwordless authentication from GitHub Actions to Azure using
# OpenID Connect (workload identity federation).
#
# How it works: GitHub mints a short-lived signed token describing the
# workflow run ("repo X, branch main"). Entra ID is configured to trust that
# issuer for that exact subject, and exchanges the token for an Azure access
# token. No client secret is ever created or stored.
#
# Run once. Requires: az login, and permission to create app registrations.

set -euo pipefail

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  echo "Usage: $0 <github-owner>/<repo>" >&2
  echo "Example: $0 jsamarxhi/cert-domain-checker" >&2
  exit 1
fi

APP_NAME="github-${REPO##*/}"          # ${VAR##*/} strips everything up to the last /
STATE_RG="rg-cert-checker-tfstate"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Creating app registration ${APP_NAME}..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)

echo "Creating service principal..."
az ad sp create --id "$APP_ID" --output none
# Entra can take a few seconds to replicate the new principal before role
# assignments referencing it will succeed.
sleep 20

echo "Granting Contributor on the subscription..."
az role assignment create \
  --role "Contributor" \
  --assignee "$APP_ID" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" \
  --output none

echo "Granting Storage Blob Data Contributor on the state storage account..."
# The Terraform backend authenticates to blob storage with the same identity,
# so it needs data-plane access, which Contributor alone does not grant.
STATE_SA_ID=$(az storage account list \
  --resource-group "$STATE_RG" \
  --query "[0].id" -o tsv)

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$APP_ID" \
  --scope "$STATE_SA_ID" \
  --output none

echo "Creating federated credential for refs/heads/main..."
# 'subject' must match exactly what GitHub puts in the token. A mismatch here
# is the most common cause of OIDC failures.
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${REPO}:ref:refs/heads/main\",
    \"description\": \"GitHub Actions deploy from main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" \
  --output none

cat <<MSG

Done. Add these as repository secrets:

  gh secret set AZURE_CLIENT_ID       --body "${APP_ID}"
  gh secret set AZURE_TENANT_ID       --body "${TENANT_ID}"
  gh secret set AZURE_SUBSCRIPTION_ID --body "${SUBSCRIPTION_ID}"

MSG
