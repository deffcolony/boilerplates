terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "remotely" {
  image          = "immybot/remotely:latest"
  container_name = "remotely"

  volumes = [
    "./data:/remotely-data",
  ]

  ports {
    internal = 5000
    external = 8215
  }

  restart = "unless-stopped"
}
