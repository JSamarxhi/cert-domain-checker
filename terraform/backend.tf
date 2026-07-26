# Remote state.
#
# Local state lives on one machine, which breaks the moment a CI runner needs
# to know what already exists. Storing state in Azure Blob Storage lets both
# your laptop and GitHub Actions read and write the same state, and the blob
# lease provides locking so two applies cannot run at once.
#
# Values here are filled in by scripts/bootstrap-state.sh, because the storage
# account has to exist before Terraform can use it. That chicken-and-egg step
# is why bootstrapping state is done outside Terraform.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-cert-checker-tfstate"
    storage_account_name = "stcertchecktf9863e0"
    container_name       = "tfstate"
    key                  = "cert-checker.tfstate"
    use_oidc             = true
  }
}
