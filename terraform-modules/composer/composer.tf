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
  for_each           = toset(["composer.googleapis.com"])
  disable_on_destroy = false
}

#Create a service account for GKE nodes
resource "google_service_account" "composer_service_account" {
  project      = var.project_id
  account_id   = "composer-service-account"
  display_name = "Service Account for Composer Environment, used by GKE nodes"
  depends_on = [
    google_project_service.enabled_services
  ]
}

#Grant the worker role to the service account created for composer environment
resource "google_project_iam_member" "composer_service_account_worker_role" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account.composer_service_account,
    google_project_service.enabled_services
  ]
}

#Grant the service account user role to the service account created for composer environment
resource "google_project_iam_member" "cloudcomposer_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.composer_service_account.email}"

  depends_on = [
    google_service_account.composer_service_account,
    google_project_service.enabled_services
  ]
}

#Grant the composer service agent with the needed roles to create bindings between KSA and GSA
resource "google_project_iam_member" "cloudcomposer_account_service_agent_v2_ext" {
  project = var.project_id
  role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.enabled_services
  ]
}

# Cloud Composer API Service Agent
resource "google_project_iam_member" "cloudcomposer_account_service_agent" {
  project = var.project_id
  role    = "roles/composer.serviceAgent"
  member  = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.enabled_services,
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext
  ]
}

#Create the composer environment, this module uses, composer v2 which runs on GKE auto-pilot clusters
resource "google_composer_environment" "composer_environment" {
  name     = var.composer_environment_name
  provider = google-beta
  region   = var.region
  config {
    software_config {
      image_version = "composer-2.0.27-airflow-2.2.5"
    }
    node_config {
      network         = var.vpcnetworkid
      subnetwork      = var.subnetworkid
      service_account = google_service_account.composer_service_account.email
      ip_allocation_policy {
        cluster_ipv4_cidr_block  = var.pod_ip_range
        services_ipv4_cidr_block = var.service_ip_range
      }
      tags = ["gke-composer-node"]

    }
    master_authorized_networks_config {
      enabled = true
      cidr_blocks {
        display_name = var.master_auth_cidr_name
        cidr_block   = var.master_auth_network_cidr
      }
    }
    workloads_config {
      scheduler {
        cpu        = 1
        memory_gb  = 1
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 1
        storage_gb = 1
      }
      worker {
        cpu        = 2
        memory_gb  = 10
        storage_gb = 10
        min_count  = 1
        max_count  = 4
      }
    }
    private_environment_config {
      enable_private_endpoint                = false
      master_ipv4_cidr_block                 = var.master_ip_range
      cloud_sql_ipv4_cidr_block              = var.cloud_sql_ip_range
      cloud_composer_network_ipv4_cidr_block = var.composer_tenant_ip_range
    }
    environment_size = "ENVIRONMENT_SIZE_SMALL"
  }

  depends_on = [
    google_project_iam_member.cloudcomposer_account_service_agent, 
    google_project_iam_member.cloudcomposer_account_service_agent_v2_ext
  ]

}