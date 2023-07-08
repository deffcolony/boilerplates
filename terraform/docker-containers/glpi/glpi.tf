terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "mariadb" {
  image          = "mariadb:latest"
  container_name = "glpi-mariadb"

  environment = {
    MARIADB_ROOT_PASSWORD = "Wwelkom123!"
    MARIADB_DATABASE      = "glpidb"
    MARIADB_USER          = "glpi"
    MARIADB_PASSWORD      = "Welkom123!"
  }

  volumes = [
    "./db:/var/lib/mysql",
  ]

  restart = "unless-stopped"
}

resource "docker_container" "glpi" {
  image          = "diouxx/glpi"
  container_name = "glpi"

  environment = {
    TIMEZONE = "Europe/Amsterdam"
  }

  volumes = [
    "./data:/var/www/html/glpi",
    "/etc/timezone:/etc/timezone:ro",
    "/etc/localtime:/etc/localtime:ro",
  ]

  ports {
    internal = 80
    external = 8222
  }

  restart = "unless-stopped"
}
