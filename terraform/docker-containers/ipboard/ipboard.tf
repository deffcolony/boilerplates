terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "ipboard_app" {
  name  = "ipboard"
  image = "maxime1907/ipboard:latest"

  environment = {
    MYSQL_PASSWORD    = "strongpassword!"
    MYSQL_DATABASE    = "ipboard"
    MYSQL_USER        = "ipboard"
    MYSQL_HOST        = "db"
    WEB_ALIAS_DOMAIN  = "forum.arcadeparty.lan"
    APPLICATION_UID   = "1000"
    APPLICATION_GID   = "1000"
    PGID              = "1000"
    PUID              = "1000"
    TZ                = "Europe/Amsterdam"
  }

  volumes = [
    "./data:/app",
  ]

  ports {
    internal = 80
    external = 8156
  }

  restart = "unless-stopped"
  depends_on = ["ipboard_db"]
}

resource "docker_container" "ipboard_db" {
  name  = "ipboard-mariadb"
  image = "mariadb"

  command = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW"

  environment = {
    MYSQL_ROOT_PASSWORD = "VeryStrongPassword!"
    MYSQL_PASSWORD      = "strongpassword!"
    MYSQL_DATABASE      = "ipboard"
    MYSQL_USER          = "ipboard"
  }

  volumes = [
    "./db:/var/lib/mysql",
  ]

  restart = "unless-stopped"
}
