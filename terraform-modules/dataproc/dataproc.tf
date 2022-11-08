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
  for_each           = toset(["dataproc.googleapis.com", "storage.googleapis.com"])
  disable_on_destroy = false
}

#Create a autoscaling policy for the cluster
resource "google_dataproc_autoscaling_policy" "dataproc_autoscale_policy" {
  policy_id = var.policy_id
  location  = var.region

  worker_config {
    min_instances = var.worker_min_instances
    max_instances = var.worker_max_instances
  }

  secondary_worker_config {
    min_instances = var.sec_worker_min_instances
    max_instances = var.sec_worker_max_instances
  }

  basic_algorithm {
    yarn_config {
      graceful_decommission_timeout = var.graceful_decommission_timeout
      scale_up_factor               = var.scale_up_factor
      scale_down_factor             = var.scale_down_factor
    }
  }
  depends_on = [
    google_project_service.enabled_services
  ]
}

#GCS bucket to be used by dataproc as staging bucket
resource "google_storage_bucket" "dataproc_staging_bucket" {
  name          = "bucket-stage-${var.project}"
  location      = var.region
  force_destroy = true
  depends_on = [
    google_project_service.enabled_services
  ]
}

#GCS bucket to be used by dataproc as temporary bucket
resource "google_storage_bucket" "dataproc_temp_bucket" {
  name          = "bucket-temp-${var.project}"
  location      = var.region
  force_destroy = true
  depends_on = [
    google_project_service.enabled_services
  ]
}

#A custom service account for dataproc cluster GCE nodes
resource "google_service_account" "dataproc_service_account" {
  account_id   = var.dataproc_service_account
  display_name = "Custom Service Account for the dataproc GCE nodes"
}

#Grant the node SA the editor role but this is PoC environment but in production/non-production make sure to use principle of least priviliges
resource "google_project_iam_member" "node_service_account_viewer" {
  project = var.project
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.dataproc_service_account.email}"
}

#Create a Dataproc cluster on GCE (compute engine VMs)
resource "google_dataproc_cluster" "dataproc_cluster" {
  name                          = var.dataproc_cluster_name
  region                        = var.region
  graceful_decommission_timeout = var.graceful_job_decommission_timeout
  labels = {
    environment = "proof-of-concept"
  }

  cluster_config {
    staging_bucket = google_storage_bucket.dataproc_staging_bucket.name
    temp_bucket    = google_storage_bucket.dataproc_temp_bucket.name

    gce_cluster_config {
      #network         = var.network_name
      subnetwork      = var.subnetwork_name
      service_account = google_service_account.dataproc_service_account.email
      tags            = ["dataproc-nodes"]
      service_account_scopes = [
        "cloud-platform"
      ]
      internal_ip_only = true
      shielded_instance_config {
        enable_secure_boot          = true
        enable_vtpm                 = true
        enable_integrity_monitoring = true
      }
    }

    metastore_config {
      dataproc_metastore_service = var.data_proc_metastore_svc
    }

    autoscaling_config {
      policy_uri = google_dataproc_autoscaling_policy.dataproc_autoscale_policy.name
    }

    master_config {
      num_instances = 1
      machine_type  = var.node_machine_type
      disk_config {
        boot_disk_type    = var.boot_disk_type
        boot_disk_size_gb = var.boot_disk_size
        #num_local_ssds    = var.local_ssds #e2-medium does not have local-ssd support, using e2-medium due to Google's internal env. gudilines, customer can choose VM family apt for them
      }
    }

    worker_config {
      num_instances = 2
      machine_type  = var.node_machine_type
      #Try to keep this cluster frugal, not a production grade instance of Dataproc
      #min_cpu_platform = var.min_cpu_platform
      disk_config {
        boot_disk_size_gb = var.boot_disk_size
        #num_local_ssds    = var.local_ssds #e2-medium does not have local-ssd support, using e2-medium due to Google's internal env. gudilines, customer can choose VM family apt for them
      }
    }
    #No preemptible nodes in this cluster, one can create preemptive nodes in non-prod
    #Follow these docs to configure the preemptive worker nodes:
    #https://registry.terraform.io/providers/hashicorp/google/4.38.0/docs/resources/dataproc_cluster#nested_master_config
    preemptible_worker_config {
      num_instances = 0
    }
    #Not installing any additional software components
    software_config {
      image_version = "2.0.35-debian10"
    }
  }
  depends_on = [
    google_project_service.enabled_services
  ]
}

resource "google_compute_firewall" "dataproc_allow_vm_ingress" {
  name    = "dataproc-allow-vm-ingress"
  network = var.network_name
  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }
  direction     = "INGRESS"
  source_ranges = [var.subnetwork_cidr]
  target_tags   = ["dataproc-nodes"]
}
