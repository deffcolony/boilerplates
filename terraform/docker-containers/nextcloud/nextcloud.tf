terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "nextcloud_app" {
  image          = "nextcloud"
  container_name = "nextcloud"

  environment = {
    MYSQL_PASSWORD = "strongpassword!"
    MYSQL_DATABASE = "nextcloud"
    MYSQL_USER     = "nextcloud"
    MYSQL_HOST     = "db"
  }

  volumes = [
    "./data:/var/www/html",
  ]

  ports {
    internal = 80
    external = 8130
  }

  restart = "unless-stopped"
  depends_on = ["db"]
}

resource "docker_container" "nextcloud_db" {
  image          = "mariadb"
  container_name = "nextcloud-mariadb"
  command        = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW"

  environment = {
    MYSQL_ROOT_PASSWORD = "VeryStrongPassword!"
    MYSQL_PASSWORD      = "strongpassword!"
    MYSQL_DATABASE      = "nextcloud"
    MYSQL_USER          = "nextcloud"
  }

  volumes = [
    "./db:/var/lib/mysql",
  ]

  restart = "unless-stopped"
}
