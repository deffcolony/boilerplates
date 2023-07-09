terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "mac_config" {
  name      = "MacConfig"
  driver    = "null"
  attachable = false
  internal  = false

  ipam_config {
    subnet   = "192.168.1.0/24"
    gateway  = "192.168.1.1"
    ip_range = "192.168.1.100/24"
  }

  # Set the parent value to your_networkcard_name
  driver_opts = {
    parent = "<your_networkcard_name>"
  }
}

resource "docker_network" "my_macvlan" {
  name      = "MyMacVlan"
  driver    = "macvlan"
  attachable = true
  internal  = false

  ipam_config {
    subnet   = "192.168.1.0/24"
    gateway  = "192.168.1.1"
    ip_range = "192.168.1.100/24"
  }

  # Set the parent value to your_networkcard_name
  driver_opts = {
    parent = "<your_networkcard_name>"
  }
}

resource "docker_container" "pihole" {
  name  = "pihole"
  image = "pihole/pihole:latest"

  cap_add = ["NET_ADMIN"]

  environment = {
    TZ           = "Europe/Amsterdam"
    WEBPASSWORD = "your-secret-password"
  }

  volumes = [
    "./data:/etc/pihole",
    "./dnsmasq:/etc/dnsmasq.d",
    "./lighttpd:/etc/lighttpd",
    "./errorpage:/var/www/html/pihole",
  ]

  ports {
    internal = 53
    external = 8124
    protocol = "tcp"
  }

  ports {
    internal = 53
    external = 8124
    protocol = "udp"
  }

  ports {
    internal = 67
    external = 8123
    protocol = "udp"
  }

  ports {
    internal = 80
    external = 8122
    protocol = "tcp"
  }

  ports {
    internal = 443
    external = 8121
    protocol = "tcp"
  }

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.my_macvlan.name
    ipv4_address = "192.168.1.123"
  }
}
