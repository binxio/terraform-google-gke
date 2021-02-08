locals {
  owner       = "myself"
  project     = var.project
  environment = var.environment
}

data "google_project" "project" {}

module "gke" {
  source = "../../"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  purpose = "terratest"

  # GKE Settings
  network                = var.network
  subnetwork             = var.subnetwork
  master_ipv4_cidr_block = "10.0.0.0/28"
  master_authorized_networks = {
    "10.10.0.0/18" = "local-network"
  }

  workload_identity_config = [{
    identity_namespace = format("%s.svc.id.goog", data.google_project.project.project_id)
  }]

  database_encryption_kms_key = "" # data.google_kms_crypto_key.shared.self_link

  # Provide generic defaults for our nodepools so we don't have to set them for each of them seperately.
  # Merged with the module's node_pool_defaults output to fill in missing variables
  node_pool_defaults = merge(
    module.gke.node_pool_defaults,
    {
      workload_metadata_config = [{
        node_metadata = "GKE_METADATA_SERVER" # Enables workload identity on the node.
      }]
    }
  )

  node_pools = {
    "primary" = {
      service_account = var.service_account
      disk_size_gb    = 10
      min_node_count  = 0
      max_node_count  = 2
      node_count      = 1
      tags            = ["allow-internet"]
      labels = {
        "mylabel" = "6"
      }
    }
  }

  release_channel = {
    channel = "REGULAR"
  }
}

output "gke" {
  value     = module.gke
  sensitive = true
}
