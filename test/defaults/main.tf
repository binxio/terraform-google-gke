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

  purpose = "terratest"

  # GKE Settings
  network                = var.network
  subnetwork             = var.subnetwork
  master_ipv4_cidr_block = "10.0.0.0/28"
  master_authorized_networks = {
    "10.10.0.0/18" = "local-network"
  }

  database_encryption_kms_key = "" # data.google_kms_crypto_key.shared.self_link

  node_pools = {
    "primary" = {
      service_account = var.service_account
    }
  }
}

output "gke" {
  value = module.gke
}
