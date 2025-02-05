variable "ssh_key_name" {
  type = string
}
variable "region" {
  type    = string
  default = "fra1"
}
variable "size" {
  type    = string
  default = "s-1vcpu-1gb"
}
variable "name" {
  description = "Droplet name"
  type        = string
  default     = "web"
}
variable "apex_domain" {
  description = "Domain registered in CloudFlare"
  type        = string
}
variable "subdomain" {
  type = string
}
variable "admin_ips" {
  description = "Comma separated CIDRs"
  type        = string
}
