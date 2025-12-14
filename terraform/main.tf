terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_ssh_key" "wail_key" {
  name       = "wail-devops-key"
  public_key = file(var.ssh_public_key_path)
}

resource "digitalocean_droplet" "portfolio_server" {
  name       = var.droplet_name
  size       = var.droplet_size
  image      = var.droplet_image
  region     = var.droplet_region
  ssh_keys   = [digitalocean_ssh_key.wail_key.id]
  monitoring = true
  tags       = ["portfolio", "production", "terraform"]
}

resource "digitalocean_database_cluster" "postgres" {
  name       = var.database_name
  engine     = "pg"
  version    = var.database_version
  size       = var.database_size
  region     = var.droplet_region
  node_count = 1
  tags       = ["portfolio", "production", "terraform"]
}

resource "digitalocean_database_db" "uptime_kuma_db" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "uptime_kuma"
}

resource "digitalocean_database_user" "uptime_kuma_user" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "uptime_kuma"
}

resource "digitalocean_database_firewall" "postgres_firewall" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "droplet"
    value = digitalocean_droplet.portfolio_server.id
  }
}
