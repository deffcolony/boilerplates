terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
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
