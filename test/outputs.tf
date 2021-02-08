output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnets" {
  value = module.vpc.map
}

output "vpc_vars" {
  value = local.vpc
}

output "gke_sa" {
  value = module.gke_sa.map["gke-test"].email
}

output "key_ring_name" {
  value = module.key_ring.key_ring_name
}

output "key_ring" {
  value = module.key_ring.key_ring
}

output "crypto_key_name" {
  value = module.gke_crypto_key.crypto_key_name
}

output "crypto_key" {
  value = module.gke_crypto_key.crypto_key
}
