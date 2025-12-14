variable "do_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "droplet_name" {
  type    = string
  default = "wail-portfolio-vps"
}

variable "droplet_size" {
  type    = string
  default = "s-2vcpu-4gb"
}

variable "droplet_image" {
  type    = string
  default = "ubuntu-22-04-x64"
}

variable "droplet_region" {
  type    = string
  default = "fra1"
}

variable "ansible_user" {
  type    = string
  default = "wail"
}

variable "database_name" {
  type    = string
  default = "wail-portfolio-db"
}

variable "database_version" {
  type    = string
  default = "16"
}

variable "database_size" {
  type    = string
  default = "db-s-1vcpu-1gb"
}
