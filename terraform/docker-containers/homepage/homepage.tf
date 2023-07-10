terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "homepage" {
  image   = "ghcr.io/benphelps/homepage:latest"
  name    = "hpage"
  ports {
    internal = 3000
    external = 8101
  }
  restart = "unless-stopped"
  
  volumes {
    container_path = "/app/config"
    host_path      = "/home/gebruikersnaam/terraform/homepage/config"
  }

  volumes {
    container_path = "/app/public/icons"
    host_path      = "/home/gebruikersnaam/terraform/homepage/icons"
  }

  volumes {
    container_path = "/app/public/images"
    host_path      = "/home/gebruikersnaam/terraform/homepage/images"
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = true
  }


}