variable "region" {}
variable "project" {}
variable "network_name" {}
variable "subnetwork_name" {}
variable "subnetwork_cidr" {}
variable "data_proc_metastore_svc" {}
variable "worker_max_instances" {
  default = 5
}
variable "worker_min_instances" {
  default = 2
}
variable "sec_worker_max_instances" {
  default = 2
}
variable "sec_worker_min_instances" {
  default = 0
}
variable "graceful_decommission_timeout" {
  default = "30s"
}
variable "scale_up_factor" {
  default = 0.5
}
variable "scale_down_factor" {
  default = 0.5
}
variable "policy_id" {
  default = "dataproc-autoscale-policy"
}
variable "dataproc_cluster_name" {
  default = "ds-dataproc-cluster-us-central-01"
}
variable "env" {
  default = "proof-of-concept"
}
variable "graceful_job_decommission_timeout" {
  default = "120s"
}
variable "boot_disk_type" {
  default = "pd-ssd"
}
variable "boot_disk_size" {
  default = 50
}
variable "node_machine_type" {
  default = "e2-medium"
}
variable "min_cpu_platform" {
  default = "Intel Skylake"
}
variable "local_ssds" {
  default = 1
}
variable "dataproc_service_account" {
  default = "dataproc-node-sa"
}