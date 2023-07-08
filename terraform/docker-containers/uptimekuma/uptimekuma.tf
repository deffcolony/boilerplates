terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "uptimekuma" {
  image          = "louislam/uptime-kuma:latest"
  container_name = "uptimekuma"

  volumes = [
    "./data:/app/data",
    "/var/run/docker.sock:/var/run/docker.sock",
  ]

  ports {
    internal = 3001
    external = 8160
  }

  restart = "unless-stopped"
}
