locals {
  owner       = "myself"
  project     = var.project
  environment = var.environment
}

module "gke" {
  source = "../../"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  purpose = "terratest this is way too long and contains invalid chars!!!"

  # GKE Settings
  network    = var.network
  subnetwork = var.subnetwork
  private_cluster_config = {
    master_ipv4_cidr_block = "10.0.0.0/21"
  }

  master_authorized_networks = {
    "10.10.0.0/18" = "local-network"
  }
  database_encryption_kms_key = "projects/sandbox-global-test/locations/this-location-is-different/mykeyring/keys/in-a-different-region"

  node_pools = {
    "primary" = {
      service_account = var.service_account
    }
  }
}

output "gke" {
  value = module.gke
}
