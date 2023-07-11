terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "mariadb" {
  image = "mariadb:latest"
  name  = "glpi-mariadb"
  restart = "unless-stopped"

  env = [
    MARIADB_ROOT_PASSWORD = "Wwelkom123!"
    MARIADB_DATABASE      = "glpidb"
    MARIADB_USER          = "glpi"
    MARIADB_PASSWORD      = "Welkom123!"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/glpi/db"
    container_path = "/var/lib/mysql"
  }


}

resource "docker_container" "glpi" {
  image = "diouxx/glpi"
  name  = "glpi"
  ports {
    internal = 80
    external = 8222
  }
  restart = "unless-stopped"

  env = [
    "TIMEZONE = Europe/Amsterdam"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/glpi/data"
    container_path = "/var/www/html/glpi"
  }

  volumes {
    host_path      = "/etc/timezone"
    container_path = "/etc/timezone"
  }

  volumes {
    host_path      = "/etc/localtime"
    container_path = "/etc/localtime"
  }


}
