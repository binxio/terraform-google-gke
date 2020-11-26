variable "subnetwork" {
  description = "The name output of created subnet for GKE"
  type        = string
}

variable "network" {
  description = "The self_link output of created vpc for GKE"
  type        = string
}

variable "database_encryption_kms_key" {
  description = "The KMS key self_link to use for database encryption"
  type        = string
}

variable "service_account" {
  description = "The service_account to use for the cluster nodes"
  type        = string
}
