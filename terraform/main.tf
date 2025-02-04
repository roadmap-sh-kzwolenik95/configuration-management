data "digitalocean_images" "available" {
  filter {
    key    = "distribution"
    values = ["Fedora"]
  }
  filter {
    key    = "regions"
    values = ["fra1"]
  }
  filter {
    key    = "type"
    values = ["base"]
  }
  sort {
    key       = "created"
    direction = "desc"
  }
}

resource "digitalocean_droplet" "fedora" {
  image  = data.digitalocean_images.available.images[0].slug
  name   = var.name
  region = var.region
  size   = var.size
  ssh_keys = [
    data.digitalocean_ssh_key.terraform.id
  ]
  tags = [ "roadmapsh-fedora-web" ]
}

data "http" "runner_ip" {
  url = "http://checkip.amazonaws.com"
}

data "cloudflare_ip_ranges" "cloudflare" {}

resource "digitalocean_firewall" "allow_cloudflare" {
  name = "Allow-CloudFlare"

  droplet_ids = [digitalocean_droplet.fedora.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
  }
}

resource "digitalocean_firewall" "allow_all_http" {
  name = "Allow-All-Http"

  droplet_ids = [digitalocean_droplet.fedora.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "allow_all_outbound" {
  name = "Allow-All-Outbound"

  droplet_ids = [digitalocean_droplet.fedora.id]

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "allow_runner" {
  name = "Allow-Runner"

  droplet_ids = [digitalocean_droplet.fedora.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["${chomp(data.http.runner_ip.response_body)}/32"]
  }
}

data "cloudflare_zone" "domain-zone" {
  name = var.apex_domain
}

resource "cloudflare_record" "url" {
  zone_id = data.cloudflare_zone.domain-zone.id
  name    = var.subdomain
  content = resource.digitalocean_droplet.fedora.ipv4_address
  type    = "A"
  proxied = false
}
