variable "project" {}
variable "project_id" {}
variable "project_number" {}
variable "composer_environment_name" {
  default = "target-ds-demo"
}
variable "region" {}
variable "vpcnetworkid" {}
variable "subnetworkid" {}
variable "pod_ip_range" {}
variable "service_ip_range" {}
variable "master_auth_cidr_name" {}
variable "master_auth_network_cidr" {}
variable "master_ip_range" {}
variable "cloud_sql_ip_range" {}
variable "composer_tenant_ip_range" {}