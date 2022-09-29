terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
    }
  }
}

#Enable the required services needed for execution
resource "google_project_service" "enabled_services" {
  project            = var.project
  service            = each.key
  for_each           = toset(["compute.googleapis.com", "servicenetworking.googleapis.com"])
  disable_on_destroy = false
}

#Create a custom vpc network
resource "google_compute_network" "composer_vpc_network" {
  project                 = var.project
  name                    = var.vpcnetworkname
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on = [
    google_project_service.enabled_services
  ]
}

#Create a subnetwork in us-central1 region
resource "google_compute_subnetwork" "composer_vpc_subnetwork" {
  project                  = var.project
  name                     = var.vpcsubnetworkname
  region                   = var.region
  network                  = google_compute_network.composer_vpc_network.id
  ip_cidr_range            = var.subnetwork_cidr
  private_ip_google_access = true
  depends_on = [
    google_project_service.enabled_services
  ]
}

#Create a router in us-central1 region
resource "google_compute_router" "composer_vpc_regional_router" {
  project = var.project
  name    = var.routername
  network = google_compute_network.composer_vpc_network.name
  region  = var.region
  bgp {
    asn = var.asn
  }
  #Router should be up before CloudNAT can use it, wait for 10 seconds
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [
    google_project_service.enabled_services
  ]
}

#Create a CloudNAT Gateway using the router, you must have the default internet gateway as a next hop for 0.0.0.0/0 for CloudNAT
resource "google_compute_router_nat" "composer_vpc_regional_nat" {
  project                            = var.project
  name                               = var.natgateway
  router                             = google_compute_router.composer_vpc_regional_router.name
  region                             = google_compute_router.composer_vpc_regional_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.composer_vpc_subnetwork.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}