locals {
  owner       = "myself"
  project     = var.project
  environment = var.environment

  vpc = {
    network_name = "private-gke"
    subnets = {
      "gke-asserts" = {
        ip_cidr_range = "10.20.0.0/25"
        region        = "europe-west4"
      }
      "gke-k8nodes" = {
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
}

module "vpc" {
  source  = "binxio/network-vpc/google"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  network_name = local.vpc.network_name
  subnets      = local.vpc.subnets
  routes       = local.vpc.routes
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

  name = "terratest"
}

module "gke_crypto_key" {
  source  = "binxio/kms/google//modules/crypto_key"
  version = "~> 1.0.0"

  owner       = local.owner
  project     = local.project
  environment = local.environment

  name     = "terratest-gke"
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
