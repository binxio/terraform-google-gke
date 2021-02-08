#------------------------------------------------------------------------------------------------------------------------
# 
# Generic variables
#
#------------------------------------------------------------------------------------------------------------------------
variable "owner" {
  description = "Owner of the resource. This variable is used to set the 'owner' label."
  type        = string
}

variable "project" {
  description = "Company project name."
  type        = string
}

variable "environment" {
  description = "Company environment for which the resources are created (e.g. dev, tst, acc, prd, all)."
  type        = string
}

#---------------------------------------------------------------------------------------------
#
# GKE settings related variables
#
#---------------------------------------------------------------------------------------------
variable "purpose" {
  description = "The purpose for which the resources are created (e.g. gitlab-runner, backend-nodes)"
  type        = string
}

variable "location" {
  description = "Location to deploy cluster and nodes to, can be a zone or a region"
  type        = string
  default     = "europe-west4"
}

variable "workload_identity_config" {
  description = "Workload Identity allows Kubernetes service accounts to act as a user-managed Google IAM Service Account."
  type = list(object({
    identity_namespace = string
  }))
  default = []
}

variable "issue_client_certificate" {
  description = "Issue client certficate for cluster authentication"
  type        = bool
  default     = false
}

variable "region" {
  description = "The region to start the nodes in."
  type        = string
  default     = "europe-west4"
}

variable "network" {
  description = "VPC to use for the cluster, may be shared. Note that the '$subnetwork' subnetwork will be used."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork name to use for the cluster."
  type        = string
  default     = null
}

variable "security_group" {
  description = "Google (GSuite) Group to enable RBAC GKE access, format must be gke-security-groups@yourdomain.com"
  default     = null
  type        = string
}

variable "daily_maintenance_start_time" {
  description = "Start time of daily maintenance in GMT, expecting HH:MM format"
  default     = "02:00"
  type        = string
}

variable "database_encryption_kms_key" {
  description = "Supply this key to have the GKE's master etcd encrypted with specified KMS key, empty for decrypted"
  default     = ""
}

variable "node_pools" {
  description = "Node Pool definitions, one per map entry, key will be used in name"
}

variable "node_pool_defaults" {
  description = "Node Pool defaults"
  type = object({
    disk_size_gb            = number
    disk_type               = string
    guest_accelerator_type  = string
    guest_accelerator_count = number
    image_type              = string
    labels                  = map(string)
    local_ssd_count         = number
    service_account         = string
    machine_type            = string
    management              = map(string)
    max_node_count          = number
    metadata                = map(string)
    min_node_count          = number
    node_count              = number
    oauth_scopes            = list(string)
    preemptible             = bool
    tags                    = list(string)
    workload_metadata_config = list(object({
      node_metadata = string
    }))
  })
  default = null
}

variable "master_ipv4_cidr_block" {
  description = "Master IPv4 CIDR block, may not overlap with rest of the network. MUST BE A /28 !!!"
  type        = string
}
variable "master_authorized_networks" {
  type        = map(string)
  description = "Map of CIDR block -> DisplayName entries"
}

variable "min_master_version" {
  type        = string
  default     = null
  description = "Minimum master version, e.g. 1.16. Note that this bites with the release_channel setting"
}

variable "release_channel" {
  type = object({
    channel = string
  })
  default     = null
  description = "Release channel to subscribe to regarding automatic ugprades. This setting will impose version constraints to your cluster, so be careful when changing it!"
}

# Addon config variables
variable "addon_istio_enabled" {
  type    = bool
  default = false
}
variable "addon_istio_auth" {
  type        = string
  description = "AUTH_MUTUAL_TLS (strict mode) or AUTH_NONE (permissive)"
  default     = "AUTH_NONE"
}
variable "addon_kubernetes_dashboard" {
  description = "Enable Kubernetes Dashboard addon (deprecated)"
  type        = bool
  default     = false
}
variable "addon_horizontal_pod_autoscaling" {
  description = "Enable Horizontal pod addon"
  type        = bool
  default     = false
}
variable "addon_http_load_balancing" {
  description = "Enable HTTP Loadbalancing addon"
  type        = bool
  default     = true
}
variable "addon_gce_persistent_disk_csi_driver_enabled" {
  type    = bool
  default = true
}

variable "network_policy" {
  description = "Enable the network policy addon with these settings"
  type = object({
    enabled  = bool
    provider = string
  })
  default = {
    enabled  = false
    provider = "PROVIDER_UNSPECIFIED"
  }
}
