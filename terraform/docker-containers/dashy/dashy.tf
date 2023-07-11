terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "dashy" {
  image = "lissy93/dashy:latest"
  name  = "dashy"
  ports {
    internal = 80
    external = 8100
  }
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/dashy/public/conf.yml"
    container_path = "/app/public/conf.yml"
  }

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/dashy/icons"
    container_path = "/app/public/item-icons/icons"
  }


}