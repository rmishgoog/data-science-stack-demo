variable "project" {}
variable "region" {}
variable "vpcnetworkname" {}
variable "vpcsubnetworkname" {}
variable "subnetwork_cidr" {}
variable "routername" {
  default = "target-ds-demo-regional-router"
}
variable "asn" {
  default = 64514
}
variable "natgateway" {
  default = "target-ds-demo-regional-nat"
}