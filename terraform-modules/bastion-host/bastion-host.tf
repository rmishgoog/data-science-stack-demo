terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
    }
  }
}

variable "disk_size" {
    default = "50"
}
variable "machinetype" {
    default = "e2-medium"
}
variable "zone" {}
variable "project" {}
variable "network" {}
variable "subnetwork" {}
variable "service_account_id" {
  default = "bastion-node-sa"
}

resource "google_service_account" "bastion_service_account" {
  account_id   = var.service_account_id
  display_name = "Custom Service Account for the bastion host node"
}

#Grant the Edior role to the custom service account, it's too permissive, for prduction projetcs, please use principle of least priviliges
resource "google_project_iam_member" "bastion_service_account_iam_member" {
  project = var.project
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.bastion_service_account.email}"
}

#Create a simple e2-medium machine, use gcloud ssh with iap flag to ssh into this machine from the CLI, there is no public IP assigned to this VM
resource "google_compute_instance" "bastion_host" {
  name                      = "bastion-host"
  machine_type              = var.machinetype
  zone                      = var.zone
  allow_stopping_for_update = true
  tags                      = ["bastion-host"]

  boot_disk {
    initialize_params {
      size  = var.disk_size
      type  = "pd-standard"
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20220419"
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
  }

  shielded_instance_config {
    enable_secure_boot = true

  }

  service_account {
    email  = google_service_account.bastion_service_account.email
    scopes = ["cloud-platform"]
  }
}

#This firewall rule will allo IAP tunnels to facilitate SSH
resource "google_compute_firewall" "allow-iap-tunnel" {
  name    = "bastion-allow-iap-tunnel"
  network = var.network
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion-host"]
}