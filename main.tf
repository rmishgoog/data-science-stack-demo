#Assumption made is that you have an existing project in Argolis, if not, let me know if you want me to add project automation as well
#Composer environment creation can take time, be patient, generally anywhere between 30-35 minutes
#How to use this terraform code in Argolis?
# 1. Make sure your gcloud is authenticated as admin, that is use the admin@<your argolis domain>
# 2. Maker sure that the right project and billin/quota_project is set, check the current setting using gcloud config list
# 3. The code execution starts as admin but soon switches to a regular service account and then admin impersonates the service account while creating other resources
# 4. Create a terraform.tfvars file and provide values for project, project_id, project_number, gcp_account and org_id
# 5. The gcp_account is your admin@<argolis domain>
# 6. Run the terraform code with terraform init && terraform apply -auto-approve
# 7. If you do not want to create terraform.tfvars, you can pass the above variables in #4 as command line arguments
# terraform -var="project=${project}" \
# -var="project_id=${project_id}" \
# -var="project_number=${project_number}" \
# -var="gcp_account=${gcp_account}" \
# -var="org_id=${org_id}"
# 8. Be sure to provide the values for the above
# 9. CIDRs are defined in the networking module but are configurable, since it creates a brand new VPC, they should not conflict with anything
# 10.The composer environment created is a private environment, that is none of the nodes in GKE clusters are assigned public IPs and control plane is also private
# 11.Do not edit or tweak VPC firewall rules created by GKE, this will cause issues
# 12.This is kept modular for the ease of extensions and adding more services, the baseline work like networks, service accounts and org policies are done for you
# 13.If you need to add more to the core modules, please proceed
# 14.Add new modules for new services and configure them in the main.tf
# 15.Use the 'aliased' provider to make sure that your resources are not owned by admin user
# 16.Terraform does not destroy some resources like GCS buckets in the composer environment, clean it up manually

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = "4.38.0"
      #Configure the alias here so it can be passed down to a child module through provider argument.
      configuration_aliases = [google.service_principal_impersonation]
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

#Configure the provider, impersonate_service_account is the account the Org Admin will be impersonating for remaining deployment
provider "google" {
  alias                       = "service_principal_impersonation"
  project                     = var.project
  region                      = var.region
  zone                        = var.zone
  impersonate_service_account = "${var.account_id}@${var.project}.iam.gserviceaccount.com"
}

#Create the required service accounts and make the Org Admin impersonate the custom service account which has owner and org policy admin role
module "service-accounts" {
  source = "./terraform-modules/service-accounts"

  project     = var.project
  gcp_account = var.gcp_account
  org_id      = var.org_id
  account_id  = var.account_id
}

#Introduce a time delay after service accounts are created and roles assigned
resource "time_sleep" "service_account_api_activation_time_delay" {
  create_duration = "120s"
  depends_on = [
    module.service-accounts
  ]
}

#Ammend the required organization policies, composer creation will fail if OsLogin is not disabled
module "org-policies" {
  source  = "./terraform-modules/org-policies"
  project = var.project_id

  providers = { google = google.service_principal_impersonation }
  depends_on = [
    module.service-accounts,
    time_sleep.service_account_api_activation_time_delay
  ]
}

#Introduce a time delay after the org policy has been altered
resource "time_sleep" "org_policy_change_activation_time_delay" {
  create_duration = "60s"
  depends_on = [
    module.org-policies
  ]
}

module "networking" {
  source = "./terraform-modules/networking"

  project           = var.project
  region            = var.region
  vpcnetworkname    = var.vpcnetworkname
  vpcsubnetworkname = var.vpcsubnetworkname
  subnetwork_cidr   = var.subnetwork_cidr

  providers = { google = google.service_principal_impersonation }
  depends_on = [
    module.org-policies
  ]

}

module "composer" {
  source = "./terraform-modules/composer"

  project        = var.project
  project_id     = var.project_id
  project_number = var.project_number
  region         = var.region
  #vpcnetworkid             = data.google_compute_network.custom-vpc-network.id
  #subnetworkid             = data.google_compute_subnetwork.custom-vpc-sub-network.id
  #Try to use outputs from networking module instead of the data blocks
  vpcnetworkid             = module.networking.custom_vpc_network_id
  subnetworkid             = module.networking.custom_vpc_subnetwork_id
  pod_ip_range             = var.pod_ip_range
  service_ip_range         = var.service_ip_range
  master_auth_cidr_name    = var.master_auth_cidr_name
  master_ip_range          = var.master_ip_range
  cloud_sql_ip_range       = var.cloud_sql_ip_range
  composer_tenant_ip_range = var.composer_tenant_ip_range
  master_auth_network_cidr = var.subnetwork_cidr

  providers = { google = google.service_principal_impersonation }
  depends_on = [
    module.networking,
    module.org-policies
  ]
}

module "bastion-host-vm" {
  source  = "./terraform-modules/bastion-host"
  project = var.project
  zone    = var.zone

  network    = module.networking.custom_vpc_network_id
  subnetwork = module.networking.custom_vpc_subnetwork_id
  providers  = { google = google.service_principal_impersonation }

  depends_on = [
    module.networking,
    time_sleep.org_policy_change_activation_time_delay
  ]
}

module "dataproc-metastore" {
  source = "./terraform-modules/dataproc-metastore"

  project   = var.project
  region    = var.region
  network   = module.networking.custom_vpc_network_id
  providers = { google = google.service_principal_impersonation }
  depends_on = [
    module.networking,
    time_sleep.org_policy_change_activation_time_delay
  ]

}

module "dataproc-cluster" {
  source = "./terraform-modules/dataproc"

  project                 = var.project
  region                  = var.region
  network_name            = module.networking.custom_vpc_network_name
  subnetwork_name         = module.networking.custom_vpc_subnetwork_name
  subnetwork_cidr         = var.subnetwork_cidr
  data_proc_metastore_svc = module.dataproc-metastore.dataproc_metastore_svc_name

  providers = { google = google.service_principal_impersonation }
  depends_on = [
    module.networking,
    time_sleep.org_policy_change_activation_time_delay,
    module.dataproc-metastore
  ]


}

# data "google_compute_network" "custom-vpc-network" {
#   name    = var.vpcnetworkname
#   project = var.project
#   depends_on = [
#     module.networking
#   ]
# }

# data "google_compute_subnetwork" "custom-vpc-sub-network" {
#   name    = var.vpcsubnetworkname
#   project = var.project
#   region  = var.region
#   depends_on = [
#     module.networking
#   ]
# }
