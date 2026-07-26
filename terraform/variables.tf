# Input variables: the knobs for this configuration.
# Values come from terraform.tfvars, -var flags, or TF_VAR_* env vars.

variable "subscription_id" {
  description = "Azure subscription ID to deploy into. Find it with: az account show --query id -o tsv"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Name prefix applied to every resource, so they group together and don't collide."
  type        = string
  default     = "cert-checker"
}

variable "container_image" {
  description = "Fully qualified container image to deploy."
  type        = string
  default     = "ghcr.io/jsamarxhi/cert-checker:latest"
}

variable "target_port" {
  description = "Port the container listens on. Must match EXPOSE/uvicorn in the Dockerfile."
  type        = number
  default     = 8000
}
