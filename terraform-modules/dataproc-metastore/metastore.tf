terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
    }
  }
}

variable "project" {}
variable "network" {}
variable "region" {}
variable "release_channel" {
  default = "STABLE"
}
#Choosing MYSQL as the database type, other option is Google 
variable "database_type" {
  default = "MYSQL"
}
#Make the service available at 9080, this can be overridden if needed
variable "port" {
  type    = string
  default = "9080"
}
#Create a developer tier in demo environment, one can choose ENTERPRISE for production environment
variable "tier" {
  type    = string
  default = "DEVELOPER"
}

#Enable the required services needed for execution
resource "google_project_service" "enabled_services" {
  project            = var.project
  service            = each.key
  for_each           = toset(["metastore.googleapis.com"])
  disable_on_destroy = false
}

#Create the dataproc metastore service
resource "google_dataproc_metastore_service" "dataproc_metastore" {
  project         = var.project
  service_id      = "ds-demo-dataproc-metastore"
  location        = var.region
  port            = var.port
  tier            = var.tier
  release_channel = var.release_channel
  database_type   = var.database_type

  maintenance_window {
    hour_of_day = 2
    day_of_week = "SUNDAY"
  }
  hive_metastore_config {
    version = "3.1.2"

  }
  network = var.network
  depends_on = [
    google_project_service.enabled_services
  ]
}

output "dataproc_metastore_svc_name" {
  value = google_dataproc_metastore_service.dataproc_metastore.name
}