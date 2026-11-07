variable "location" {
  description = "Azure region for the demo resources."
  type        = string
  default     = "eastus"
}

variable "registry_name" {
  description = "Existing persistent ACR created by the state bootstrap, retained through cluster teardown."
  type        = string
}

variable "registry_resource_group" {
  description = "Persistent state/artifact resource group, outside cluster teardown."
  type        = string
}

variable "name_prefix" {
  description = "Lowercase prefix used for demo resource names."
  type        = string
  default     = "nrobsdemo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.name_prefix))
    error_message = "name_prefix must be 3-16 lowercase letters, digits, or hyphens and start with a letter."
  }
}

variable "node_count" {
  description = "Fixed one-node footprint for this temporary, non-HA lab to bound compute cost."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count == 1
    error_message = "node_count must remain 1 to keep this temporary lab's compute footprint bounded."
  }
}

variable "node_vm_size" {
  description = "AKS node VM size; the upstream demo requires about 6 GB free memory. Verify regional price and availability."
  type        = string
  default     = "Standard_D4as_v5"
}

variable "github_actions_principal_object_id" {
  description = "Object ID of the GitHub OIDC service principal, granted AKS RBAC Cluster Admin on this demo cluster."
  type        = string
}