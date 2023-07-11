terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "uptimekuma" {
  image = "louislam/uptime-kuma:latest"
  name  = "uptimekuma"
  ports {
    internal = 3001
    external = 8160
  }
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/uptimekuma/data"
    container_path = "/app/data"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }


}
