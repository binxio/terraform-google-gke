#---------------------------------------------------------------------------------------------
# Locals for readability
#---------------------------------------------------------------------------------------------

locals {
  project     = var.project
  environment = var.environment
  owner       = var.owner
  purpose     = var.purpose

  # Startpoint for our node pool defaults
  module_node_pool_defaults = {
    disk_size_gb            = 100
    disk_type               = "pd-ssd" # or "pd-standard"
    guest_accelerator_type  = null
    guest_accelerator_count = 0
    image_type              = null
    labels                  = local.labels
    machine_type            = "n1-standard-1"
    max_node_count          = 0
    min_node_count          = 0
    node_count              = 0
    local_ssd_count         = 0
    service_account         = null
    management = {
      auto_repair  = can(var.release_channel) && try(var.release_channel.channel, null) == "REGULAR" ? true : false
      auto_upgrade = can(var.release_channel) && try(var.release_channel.channel, null) == "REGULAR" ? true : false
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
    oauth_scopes = [                                   # These scopes limit access to what you can access, ie. even if your serviceaccount is admin, it still can't reach it if the scope does not include it.
      "https://www.googleapis.com/auth/cloud-platform" # Default allows all cloud services.
    ]
    preemptible              = false
    tags                     = []
    owner                    = var.owner
    workload_metadata_config = []
  }
  # Merge defaults with module defaults and user provided variables
  node_pool_defaults = var.node_pool_defaults == null ? local.module_node_pool_defaults : merge(local.module_node_pool_defaults, var.node_pool_defaults)

  gke_sa = format("gke-%s", local.purpose)

  labels = {
    "creator"     = "terraform"
    "project"     = substr(replace(lower(local.project), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
    "environment" = substr(replace(lower(local.environment), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
    "purpose"     = substr(replace(lower(local.purpose), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
    "owner"       = substr(replace(lower(local.owner), "/[^\\p{Ll}\\p{Lo}\\p{N}_-]+/", "_"), 0, 63)
  }

  name = replace(lower(format("%s-%s-%s", local.project, local.environment, var.purpose)), "/[^\\p{Ll}\\p{Lo}\\p{N}-]+/", "-")

  pool_name_prefix = replace(format("%s", lower(local.purpose)), "/[^\\p{Ll}\\p{Lo}\\p{N}-]+/", "-")
  node_pools = {
    for node_pool, settings in var.node_pools : node_pool => merge(local.node_pool_defaults, settings)
  }
  service_account = [for n, s in local.node_pools : s.service_account][0]

  # See how the network was supplied
  # IF it has a slash, it's long notation including project, otherwise it's just the name.
  network_regex   = "^projects/(?P<project>[^/]+).*?/(?P<network>[^/]+)?$"
  network_name    = (length(regexall("/", var.network)) > 0 ? regex(local.network_regex, var.network)["network"] : var.network)
  network_project = (length(regexall("/", var.network)) > 0 ? regex(local.network_regex, var.network)["project"] : null)

  subnetwork = var.subnetwork
}

#---------------------------------------------------------------------------------------------
# Service Account is provided through variables since we have chickens and eggs with IAM
#---------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------
# Data sources
#---------------------------------------------------------------------------------------------
data "google_compute_network" "net" {
  name    = local.network_name
  project = local.network_project
}

data "google_compute_subnetwork" "subnet" {
  name    = local.subnetwork
  project = local.network_project
  region  = var.region
}

data "google_container_cluster" "exists" {
  name     = local.name
  location = var.location
}

#---------------------------------------------------------------------------------------------
# GKE Cluster
#---------------------------------------------------------------------------------------------
resource "google_container_cluster" "gke" {
  provider                 = google-beta
  name                     = local.name
  resource_labels          = local.labels
  location                 = var.location
  remove_default_node_pool = true
  initial_node_count       = 1

  # NOTE:
  # Do _NOT_ add a node_config{} block here, see https://github.com/terraform-providers/terraform-provider-google/issues/2115
  # Created https://github.com/terraform-providers/terraform-provider-google/issues/4435 for it.
  # It will cause this cluster to be recreated all the time due to changing settings within the provider.
  # "As shown in the recommended example, node_config should be omitted and node_pool should be omitted."
  # The initial node here is required for cluster creation but deleted immediately after.
  # HACK FOR INITIAL CREATION:
  dynamic "node_config" {
    for_each = coalesce(data.google_container_cluster.exists.endpoint, "!") == "!" ? { foo : "bar" } : {}

    content {
      service_account = local.service_account
      tags            = distinct(flatten([for pool in local.node_pools : try(pool.tags, [])]))
    }
  }

  dynamic "workload_identity_config" {
    for_each = var.workload_identity_config

    content {
      identity_namespace = workload_identity_config.value.identity_namespace
    }
  }

  master_auth {
    client_certificate_config { # This disables basic auth
      issue_client_certificate = var.issue_client_certificate
    }
  }

  dynamic "authenticator_groups_config" {
    for_each = var.security_group != null ? [var.security_group] : []

    content {
      security_group = var.security_group
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8pods"
    services_secondary_range_name = "k8services"
  }

  logging_service    = "logging.googleapis.com/kubernetes"    # "the Google Cloud Logging service with Kubernetes-native resource model in Stackdriver"
  monitoring_service = "monitoring.googleapis.com/kubernetes" # this one and logging_service need to both be set to the same type of endpoint
  subnetwork         = data.google_compute_subnetwork.subnet.self_link
  network            = data.google_compute_network.net.self_link

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    master_global_access_config {
      enabled = true
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [var.master_authorized_networks] : []

    content {
      dynamic "cidr_blocks" {
        for_each = master_authorized_networks_config.value
        iterator = man

        content {
          cidr_block   = man.key
          display_name = man.value
        }
      }
    }
  }

  addons_config {
    http_load_balancing {
      disabled = !var.addon_http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = !var.addon_horizontal_pod_autoscaling
    }
    istio_config {
      disabled = !var.addon_istio_enabled
      auth     = var.addon_istio_auth
    }
    gce_persistent_disk_csi_driver_config {
      enabled = var.addon_gce_persistent_disk_csi_driver_enabled
    }
    network_policy_config {
      disabled = !(var.network_policy != null && var.network_policy.enabled)
    }
  }

  dynamic "network_policy" {
    for_each = var.network_policy != null && var.network_policy.enabled ? [var.network_policy] : []

    content {
      provider = network_policy.value.provider
      enabled  = network_policy.value.enabled
    }
  }

  database_encryption {
    state    = var.database_encryption_kms_key != "" ? "ENCRYPTED" : "DECRYPTED"
    key_name = var.database_encryption_kms_key != "" ? var.database_encryption_kms_key : ""
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.daily_maintenance_start_time
    }
  }

  dynamic "release_channel" {
    for_each = var.release_channel != null ? [var.release_channel] : []
    content {
      channel = release_channel.value.channel
    }
  }
  min_master_version = var.min_master_version

  networking_mode = "VPC_NATIVE"

  # Below added due to #4435
  lifecycle {
    ignore_changes = [node_pool, node_config, initial_node_count]
  }
}

resource "google_container_node_pool" "pools" {
  provider = google-beta

  for_each = local.node_pools
  cluster  = google_container_cluster.gke.name

  name       = format("%s-%s", local.pool_name_prefix, lower(replace(each.key, " ", "-")))
  location   = var.location
  node_count = (each.value.node_count == 0 ? null : each.value.node_count)
  dynamic "autoscaling" {
    for_each = each.value.max_node_count != 0 ? [each.value.max_node_count] : []
    content {
      min_node_count = each.value.min_node_count
      max_node_count = each.value.max_node_count
    }
  }
  management {
    auto_repair  = try(each.value.management.auto_repair, null)
    auto_upgrade = try(each.value.management.auto_upgrade, null)
  }
  node_config {
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    dynamic "guest_accelerator" {
      for_each = each.value.guest_accelerator_type != null ? [each.value.guest_accelerator_type] : []
      content {
        type  = each.value.guest_accelerator_type
        count = each.value.guest_accelerator_count
      }
    }

    image_type      = each.value.image_type # Changing this will nuke all nodes!
    labels          = each.value.labels
    local_ssd_count = each.value.local_ssd_count
    machine_type    = each.value.machine_type
    metadata        = merge(each.value.metadata, { disable-legacy-endpoints = "true" })
    oauth_scopes    = each.value.oauth_scopes
    preemptible     = each.value.preemptible
    service_account = each.value.service_account
    tags            = each.value.tags

    dynamic "workload_metadata_config" {
      for_each = each.value.workload_metadata_config

      content {
        node_metadata = workload_metadata_config.value.node_metadata
      }
    }
  }
}
