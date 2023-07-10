terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "portainer" {
  image        = "portainer/portainer-ce:latest" # For Business Edition use: portainer/portainer-ee:latest
  name         = "portainer"

  ports {
    internal = 8000
    external = 8000
  }
  ports {
    internal = 9000
    external = 9000
  }
  
  restart      = "always"

  volumes {
    container_path = "/data"
    host_path      = "/home/gebruikersnaam/terraform/portainer/data"
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
  }


}