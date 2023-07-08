 terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "wireguard" {
  image   = "linuxserver/wireguard"
  name    = "wireguard"
  cap_add = ["NET_ADMIN", "SYS_MODULE"]
  environment = {
    PUID             = "1000"
    PGID             = "1000"
    TZ               = "Europe/Amsterdam"
    SERVERURL        = "auto"  # Set to your desired server URL
    SERVERPORT       = "51820" # Optional
    PEERS            = "1"     # Optional
    PEERDNS          = "auto"  # Optional
    INTERNAL_SUBNET  = "10.13.13.0"  # Optional
  }
  sysctls = ["net.ipv4.conf.all.src_valid_mark=1"]
  volumes = [
    "./config:/config",
    "/lib/modules:/lib/modules",
  ]
  ports {
    internal = 51820
    external = 51820
    protocol = "udp"
  }
  restart = "unless-stopped"
}
