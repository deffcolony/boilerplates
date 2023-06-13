terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "portainer" {
  image        = "portainer/portainer-ce:latest"
  name         = "portainer"
  volumes      = ["./portainer:/data", "/var/run/docker.sock:/var/run/docker.sock"]
  ports {
    internal = 8000
    external = 8000
  }
  ports {
    internal = 9000
    external = 9000
  }
  restart      = "always"
}