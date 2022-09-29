variable "region" {
  default = "us-central1"
}
variable "zone" {
  default = "us-central1-c"
}
variable "vpcnetworkname" {
  default = "ds-demo-vpc-network"
}
variable "vpcsubnetworkname" {
  default = "ds-demo-vpc-subnet-us-central"
}
variable "subnetwork_cidr" {
  default = "10.1.0.0/24"
}
variable "project_id" {}
variable "project" {}
variable "project_number" {}
variable "gcp_account" {}
variable "org_id" {}
variable "pod_ip_range" {
  default = "10.32.0.0/16"
}
variable "service_ip_range" {
  default = "10.34.0.0/20"
}
variable "master_auth_cidr_name" {
  default = "master_authorized_net_cidr"
}
variable "master_ip_range" {
  default = "172.16.0.0/28"
}
variable "cloud_sql_ip_range" {
  default = "10.2.0.0/24"
}
variable "composer_tenant_ip_range" {
  default = "192.168.0.0/24"
}
variable "account_id" {
  default = "ds-demo-deploy"
}