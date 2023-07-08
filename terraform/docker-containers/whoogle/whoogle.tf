terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "whoogle" {
  image        = "benbusby/whoogle-search:latest"
  name         = "whoogle"
  ports {
    internal = 5000
    external = 8140
  }
  restart      = "unless-stopped"
}
