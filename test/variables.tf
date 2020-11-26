variable "environment" {
  description = "Allows us to use random environment for our tests"
  type        = string
}

variable "project" {
  description = "Allows us to use random project for our tests"
  type        = string
}

variable "location" {
  description = "Allows us to use random location for our tests"
  type        = string
}

variable "owner" {
  description = "Owner used for tagging"
  type        = string
}

variable "subnetwork" {
  description = "The name output of created subnet for GKE"
  type        = string
}

variable "network" {
  description = "The self_link output of created vpc for GKE"
  type        = string
}

variable "database_encryption_kms_key" {
  description = "The KMS key to use for database encryption"
	type        = string
}

variable "service_account" {
  description = "The service_account to use for the cluster nodes"
  type        = string
}
