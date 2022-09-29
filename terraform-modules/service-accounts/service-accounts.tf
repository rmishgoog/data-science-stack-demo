terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
    }
  }
}

variable "project" {}
variable "gcp_account" {}
variable "org_id" {}
variable "account_id" {}


#Create a service account for tweaking the org policy
resource "google_service_account" "ds_demo_deploy_service_account" {
  project      = var.project
  account_id   = var.account_id
  display_name = "Service Account data science PoC environment"
}

#Grant this account the owner role
resource "google_project_iam_member" "ds_demo_deploy_service_account_owner_role" {
  project = var.project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.ds_demo_deploy_service_account.email}"

  depends_on = [
    google_service_account.ds_demo_deploy_service_account
  ]
}

#Grant the org policy admin role to this account
resource "google_organization_iam_member" "ds_demo_deploy_service_account__org_policy_role" {
  org_id = var.org_id
  role   = "roles/orgpolicy.policyAdmin"
  member = "serviceAccount:${google_service_account.ds_demo_deploy_service_account.email}"

  depends_on = [
    google_service_account.ds_demo_deploy_service_account
  ]
}

#Impersonate this service account before trying to change the org policy
resource "google_service_account_iam_member" "ds_demo_deploy_org_policy_admin_account_impersonation" {
  service_account_id = google_service_account.ds_demo_deploy_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.gcp_account}"

  depends_on = [
    google_project_iam_member.ds_demo_deploy_service_account_owner_role,
    google_organization_iam_member.ds_demo_deploy_service_account__org_policy_role
  ]
}