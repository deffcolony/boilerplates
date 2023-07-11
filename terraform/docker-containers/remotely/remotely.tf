terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "remotely" {
  image = "immybot/remotely:latest"
  name  = "remotely"
  ports {
    internal = 5000
    external = 8215
  }
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/remotely/data"
    container_path = "/remotely-data"
  }

}
