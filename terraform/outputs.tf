output "server_ip" {
  value = digitalocean_droplet.portfolio_server.ipv4_address
}

output "server_id" {
  value = digitalocean_droplet.portfolio_server.id
}

output "ssh_command" {
  value = "ssh wail@${digitalocean_droplet.portfolio_server.ipv4_address}"
}

output "database_host" {
  value = digitalocean_database_cluster.postgres.host
}

output "database_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "database_user" {
  value = digitalocean_database_user.uptime_kuma_user.name
}

output "database_password" {
  value     = digitalocean_database_user.uptime_kuma_user.password
  sensitive = true
}

output "database_uri" {
  value     = "postgresql://${digitalocean_database_user.uptime_kuma_user.name}:${digitalocean_database_user.uptime_kuma_user.password}@${digitalocean_database_cluster.postgres.host}:${digitalocean_database_cluster.postgres.port}/${digitalocean_database_db.uptime_kuma_db.name}?sslmode=require"
  sensitive = true
}
