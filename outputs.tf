output "node_pool_defaults" {
  description = "The generic defaults used for node_pool settings"
  value       = local.module_node_pool_defaults
}

output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke.name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint, might be private"
  value       = google_container_cluster.gke.endpoint
}
output "gke_cluster_master_version" {
  description = "Master version running on GKE cluster, which can differ from specified minimum version"
  value       = google_container_cluster.gke.master_version
}
output "gke_cluster_maintenance_window_duration" {
  value       = google_container_cluster.gke.maintenance_policy.0.daily_maintenance_window.0.duration
  description = "Daily maintenance window duration in RFC3339 format"
}
output "gke_cluster_services_ipv4_cidr" {
  description = "IPv4 CIDR of services range"
  value       = google_container_cluster.gke.services_ipv4_cidr
}
# output "gke_cluster_instance_group_urls" {
#   value       = google_container_cluster.gke.instance_group_urls
#   description = "URLs of instance groups of the cluster"
# }
output "gke_instance_urls" {
  # value = google_container_node_pool.pools[*].instance_group_urls
  # Might need something like this, see https://github.com/hashicorp/terraform/issues/22476:
  value = values(google_container_node_pool.pools).*.instance_group_urls
}
output "gke_cluster_client_certificate" {
  description = "Base64 encoded client certificate to authenticate with GKE master"
  value       = google_container_cluster.gke.master_auth.0.client_certificate
  sensitive   = true
}
output "gke_cluster_client_key" {
  description = "Base64 encoded client key to authenticate with GKE master"
  value       = google_container_cluster.gke.master_auth.0.client_key
  sensitive   = true
}
output "gke_cluster_cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value       = google_container_cluster.gke.master_auth.0.cluster_ca_certificate
}

