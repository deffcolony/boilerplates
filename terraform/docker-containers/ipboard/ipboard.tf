terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "ipboard_app" {
  image = "maxime1907/ipboard:latest"
  name  = "ipboard"
  ports {
    internal = 80
    external = 8156
  }
  restart = "unless-stopped"

  env = [
    "MYSQL_PASSWORD    = strongpassword!",
    "MYSQL_DATABASE    = ipboard",
    "MYSQL_USER        = ipboard",
    "MYSQL_HOST        = db",
    "WEB_ALIAS_DOMAIN  = forum.arcadeparty.lan",
    "APPLICATION_UID   = 1000",
    "APPLICATION_GID   = 1000",
    "PGID              = 1000",
    "PUID              = 1000",
    "TZ                = Europe/Amsterdam"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/ipboard/data"
    container_path = "/app"
  }

  depends_on = ["ipboard_db"]
}

resource "docker_container" "ipboard_db" {
  image = "mariadb:latest"
  name  = "ipboard-mariadb"
  command = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW"
  restart = "unless-stopped"

  env = [
    "MYSQL_ROOT_PASSWORD = VeryStrongPassword!",
    "MYSQL_PASSWORD      = strongpassword!",
    "MYSQL_DATABASE      = ipboard",
    "MYSQL_USER          = ipboard"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/ipboard/db"
    container_path = "/var/lib/mysql"
  }


}
