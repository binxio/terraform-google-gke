locals {
  owner       = "myself"
  project     = "demo"
  environment = "dev"

  gke_subnet_name = "gke-k8nodes"
}

#############################################################
#
# Cluster configuration
#
#############################################################

module "gke" {
  source  = "binxio/gke/google"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  purpose = "demo"

  # GKE Settings
  network                = module.vpc.vpc
  subnetwork             = local.gke_subnet_name
  master_ipv4_cidr_block = "10.0.0.0/28"
  master_authorized_networks = {
    "10.10.0.0/18" = "local-network"
  }

  database_encryption_kms_key = module.gke_crypto_key.crypto_key

  # Provide generic defaults for our nodepools so we don't have to set them for each of them seperately.
  # Merged with the module's node_pool_defaults output to fill in missing variables
  node_pool_defaults = merge(
    module.gke.node_pool_defaults,
    {
      service_account = module.gke_sa.map["gke"].email
      disk_size_gb    = 10
      labels = {
        "mylabel" = "6"
      }
    }
  )

  node_pools = {
    "primary" = {
      min_node_count = 2
      max_node_count = 2
      node_count     = 1
    }
    "secondary" = {
      min_node_count = 0
      max_node_count = 4
      node_count     = 2
    }
  }

  release_channel = {
    channel = "REGULAR"
  }
}

#############################################################
#
# Set up prerequisite services
#
#############################################################

module "vpc" {
  source  = "binxio/network-vpc/google"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  network_name = "private-gke"
  subnets = {
    (local.gke_subnet_name) = {
      ip_cidr_range = "10.10.0.0/25"
      region        = "europe-west4"
      secondary_ip_ranges = [
        {
          range_name    = "k8services"
          ip_cidr_range = "10.10.0.128/27"
        },
        {
          range_name    = "k8pods"
          ip_cidr_range = "172.16.0.0/17"
        }
      ]
    }
  }
  routes = {
    "default-gateway-gke" = {
      dest_range       = "0.0.0.0/0"
      next_hop_gateway = "default-internet-gateway"
      description      = "Allow GKE nodes to bootstrap"
    }
  }
}

resource "google_compute_firewall" "iap" {
  name      = "allow-internal-all-iapssh"
  network   = module.vpc.vpc
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
  disabled = false
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

module "key_ring" {
  source  = "binxio/kms/google//modules/key_ring"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  name = "demo"
}

module "gke_crypto_key" {
  source  = "binxio/kms/google//modules/crypto_key"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  name     = "demo-gke"
  key_ring = module.key_ring.key_ring
}

module "gke_sa" {
  source  = "binxio/service-account/google"
  version = "~> 1.0.0"

  project     = local.project
  environment = local.environment

  service_accounts = {
    "gke" = {}
  }
}

