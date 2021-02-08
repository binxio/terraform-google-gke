
# Module `terraform-google-gke`

Core Version Constraints:
* `>= 0.14`

Provider Requirements:
* **google (`hashicorp/google`):** (any version)
* **google-beta:** (any version)

## Input Variables
* `addon_gce_persistent_disk_csi_driver_enabled` (default `true`)
* `addon_horizontal_pod_autoscaling` (default `false`): Enable Horizontal pod addon
* `addon_http_load_balancing` (default `true`): Enable HTTP Loadbalancing addon
* `addon_istio_auth` (default `"AUTH_NONE"`): AUTH_MUTUAL_TLS (strict mode) or AUTH_NONE (permissive)
* `addon_istio_enabled` (default `false`)
* `addon_kubernetes_dashboard` (default `false`): Enable Kubernetes Dashboard addon (deprecated)
* `daily_maintenance_start_time` (default `"02:00"`): Start time of daily maintenance in GMT, expecting HH:MM format
* `database_encryption_kms_key` (default `""`): Supply this key to have the GKE's master etcd encrypted with specified KMS key, empty for decrypted
* `environment` (required): Company environment for which the resources are created (e.g. dev, tst, acc, prd, all).
* `issue_client_certificate` (default `false`): Issue client certficate for cluster authentication
* `location` (default `"europe-west4"`): Location to deploy cluster and nodes to, can be a zone or a region
* `master_authorized_networks` (required): Map of CIDR block -> DisplayName entries
* `master_ipv4_cidr_block` (required): Master IPv4 CIDR block, may not overlap with rest of the network. MUST BE A /28 !!!
* `min_master_version` (default `null`): Minimum master version, e.g. 1.16. Note that this bites with the release_channel setting
* `network` (default `null`): VPC to use for the cluster, may be shared. Note that the '$subnetwork' subnetwork will be used.
* `network_policy` (default `{"enabled":false,"provider":"PROVIDER_UNSPECIFIED"}`): Enable the network policy addon with these settings
* `node_pool_defaults` (default `null`): Node Pool defaults
* `node_pools` (required): Node Pool definitions, one per map entry, key will be used in name
* `owner` (required): Owner of the resource. This variable is used to set the 'owner' label.
* `project` (required): Company project name.
* `purpose` (required): The purpose for which the resources are created (e.g. gitlab-runner, backend-nodes)
* `region` (default `"europe-west4"`): The region to start the nodes in.
* `release_channel` (default `null`): Release channel to subscribe to regarding automatic ugprades. This setting will impose version constraints to your cluster, so be careful when changing it!
* `security_group` (default `null`): Google (GSuite) Group to enable RBAC GKE access, format must be gke-security-groups@yourdomain.com
* `subnetwork` (default `null`): Subnetwork name to use for the cluster.
* `workload_identity_config` (default `[]`): Workload Identity allows Kubernetes service accounts to act as a user-managed Google IAM Service Account.

## Output Values
* `gke_cluster_client_certificate`: Base64 encoded client certificate to authenticate with GKE master
* `gke_cluster_client_key`: Base64 encoded client key to authenticate with GKE master
* `gke_cluster_cluster_ca_certificate`: Base64 encoded cluster CA certificate
* `gke_cluster_endpoint`: GKE cluster endpoint, might be private
* `gke_cluster_maintenance_window_duration`: Daily maintenance window duration in RFC3339 format
* `gke_cluster_master_version`: Master version running on GKE cluster, which can differ from specified minimum version
* `gke_cluster_name`: GKE cluster name
* `gke_cluster_services_ipv4_cidr`: IPv4 CIDR of services range
* `gke_instance_urls`
* `node_pool_defaults`: The generic defaults used for node_pool settings

## Managed Resources
* `google_container_cluster.gke` from `google-beta`
* `google_container_node_pool.pools` from `google-beta`

## Data Resources
* `data.google_compute_network.net` from `google`
* `data.google_compute_subnetwork.subnet` from `google`
* `data.google_container_cluster.exists` from `google`

## Creating a new release
After adding your changed and committing the code to GIT, you will need to add a new tag.
```
git tag vx.x.x
git push --tag
```
If your changes might be breaking current implementations of this module, make sure to bump the major version up by 1.

If you want to see which tags are already there, you can use the following command:
```
git tag --list
```
Required APIs
=============
For the VPC services to deploy, the following APIs should be enabled in your project:
 * `iam.googleapis.com`
 * `container.googleapis.com`
 * `cloudkms.googleapis.com`

Testing
=======
This module comes with [terratest](https://github.com/gruntwork-io/terratest) scripts for both unit testing and integration testing.
A Makefile is provided to run the tests using docker, but you can also run the tests directly on your machine if you have terratest installed.

### Run with make
Make sure to set GOOGLE_CLOUD_PROJECT to the right project and GOOGLE_CREDENTIALS to the right credentials json file
You can now run the tests with docker:
```
make test
```

### Run locally
From the module directory, run:
```
cd test && TF_VAR_owner=$(id -nu) go test
```
