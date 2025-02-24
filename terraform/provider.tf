terraform {
  cloud {
    organization = "roadmap-sh"
    hostname     = "app.terraform.io"

    workspaces {
      name = "configuration-management"
    }
  }
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "digitalocean" {}

data "digitalocean_ssh_key" "terraform" {
  name = var.ssh_key_name
}

variable "cloudflare_api_token" { sensitive = true }

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
