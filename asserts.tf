#######################################################################################################
#
# Terraform does not have a easy way to check if the input parameters are in the correct format.
# On top of that, terraform will sometimes produce a valid plan but then fail during apply.
# To handle these errors beforehad, we're using the 'file' hack to throw errors on known mistakes.
#
#######################################################################################################
locals {
  # Regular expressions

  regex_gke_cluster_name = "(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)"

  # Terraform assertion hack
  assert_head = "\n\n-------------------------- /!\\ ASSERTION FAILED /!\\ --------------------------\n\n"
  assert_foot = "\n\n-------------------------- /!\\ ^^^^^^^^^^^^^^^^ /!\\ --------------------------\n"
  asserts = {
    gke_cluster_name_too_long = length(local.name) > 100 ? file(format("%sGKE cluster [%s]'s generated name is too long:\n%s\n%s > 100 chars!%s", local.assert_head, local.purpose, local.name, length(local.name), local.assert_foot)) : "ok"
    gke_cluster_name_regex    = length(regexall("^${local.regex_gke_cluster_name}$", local.name)) == 0 ? file(format("%sGKE cluster [%s]'s generated name [%s] does not match regex ^%s$%s", local.assert_head, local.purpose, local.name, local.regex_gke_cluster_name, local.assert_foot)) : "ok"
    master_cidr_prefix_28     = can(local.private_cluster_config.master_ipv4_cidr_block) && length(regex("/28$", local.private_cluster_config.master_ipv4_cidr_block)) != 3 ? file(format("%sMaster IPv4 CIDR block should be a /28!%s", local.assert_head, local.assert_foot)) : "ok"
    subnet_exists             = coalesce(data.google_compute_subnetwork.subnet.self_link, "!") == "!" ? file(format("%sSubnet [%s] could not be found in VPC [%s]!%s", local.assert_head, local.subnetwork, var.network, local.assert_foot)) : "ok"
    secondary_range_pods      = !contains(data.google_compute_subnetwork.subnet.secondary_ip_range.*.range_name, format("k8pods")) ? file(format("%sPods secondary range [k8pods] could not be found in subnet [%s]!%s", local.assert_head, local.subnetwork, local.assert_foot)) : "ok"
    secondary_range_svc       = !contains(data.google_compute_subnetwork.subnet.secondary_ip_range.*.range_name, format("k8services")) ? file(format("%sServices secondary range [k8services] could not be found in subnet [%s]!%s", local.assert_head, local.subnetwork, local.assert_foot)) : "ok"
    # Key should be in the same location as the cluster!
    # Key would be something like projects/company-project-tst/locations/asia-east2/keyRings/company-project-tst-gke-webshop-tst/cryptoKeys/company-webshop-tst-gke-database
    key_location = coalesce(var.database_encryption_kms_key, "!") != "!" ? (regex("\\/locations\\/([^/]+)\\/", var.database_encryption_kms_key)[0] != var.location ? file(format("%sETCD Database Encryption Key specified [%s] is not in the same region as the GKE cluster [%s]! This is not allowed by GCP!%s", local.assert_head, var.database_encryption_kms_key, var.location, local.assert_foot)) : "ok") : "ok"

    nodepool_name = { for node_pool, settings in local.node_pools : node_pool => length(format("%s-%s", local.pool_name_prefix, node_pool)) >= 40 ? file("Node pool's generated name is too long. It must be less than 40 chars, pool ${node_pool} => ${format("%s-%s", local.pool_name_prefix, node_pool)} has ${length(format("%s-%s", local.pool_name_prefix, node_pool))}") : {} }


    # TODO: googleapi: Error 400: Auto_upgrade and auto_repair cannot be false when release_channel STABLE is set., badRequest
  }
}
