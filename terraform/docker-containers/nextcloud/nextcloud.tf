terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "nextcloud" {
  image = "nextcloud"
  name  = "nextcloud"
  ports {
    internal = 80
    external = 8130
  }
  restart = "unless-stopped"

  env = [
    "MYSQL_PASSWORD = strongpassword!",
    "MYSQL_DATABASE = nextcloud",
    "MYSQL_USER     = nextcloud",
    "MYSQL_HOST     = db"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/nextcloud/data"
    container_path = "/var/www/html"
  }

  depends_on = ["docker_container.nextcloud-mariadb"]
}

resource "docker_container" "nextcloud-mariadb" {
  image = "mariadb"
  name  = "nextcloud-mariadb"
  command = "--transaction-isolation=READ-COMMITTED --binlog-format=ROW"
  restart = "unless-stopped"

  env = [
    "MYSQL_ROOT_PASSWORD = VeryStrongPassword!",
    "MYSQL_PASSWORD      = strongpassword!",
    "MYSQL_DATABASE      = nextcloud",
    "MYSQL_USER          = nextcloud"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/nextcloud/db"
    container_path = "/var/lib/mysql"
  }


}
