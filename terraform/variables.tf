variable "ssh-key-name" {
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
}
variable "apex-domain" {
  description = "Domain registered in CloudFlare"
  type        = string
}
variable "subdomain" {
  type = string
}