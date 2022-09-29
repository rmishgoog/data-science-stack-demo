terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
    }
  }
}

variable "project" {}

#Enable the required services needed for execution
resource "google_project_service" "enabled_services" {
  project            = var.project
  service            = each.key
  for_each           = toset(["orgpolicy.googleapis.com"])
  disable_on_destroy = false
}

#Disable the requiredOsLogin org policy for composer to work
resource "google_org_policy_policy" "org_policy_require_os_login" {

  name   = "projects/${var.project}/policies/compute.requireOsLogin"
  parent = "projects/${var.project}"

  depends_on = [
    google_project_service.enabled_services
  ]

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}