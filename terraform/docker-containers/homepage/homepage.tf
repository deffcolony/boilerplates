terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "homepage" {
  image   = "ghcr.io/benphelps/homepage:latest"
  name    = "hpage"
  volumes = [
    "./config:/app/config",
    "./icons:/app/public/icons",
    "./images:/app/public/images",
    "/var/run/docker.sock:/var/run/docker.sock:ro",
  ]

  ports {
    internal = 3000
    external = 8101
  }

  restart = "unless-stopped"
}
