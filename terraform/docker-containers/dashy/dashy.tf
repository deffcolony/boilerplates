terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "dashy" {
  image        = "lissy93/dashy:latest"
  name         = "dashy"
  volumes      = [
    "./dashy/public/conf.yml:/app/public/conf.yml",
    "./dashy/icons:/app/public/item-icons/icons"
  ]
  ports {
    internal = 80
    external = 8100
  }
  restart      = "unless-stopped"
}