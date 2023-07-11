terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "dolibarr" {
  image   = "tuxgasy/dolibarr"
  name    = "dolibarr"
  restart = "unless-stopped"
  ports {
    internal = 80
    external = 8200
  }

  env = [
    "DOLI_DB_HOST          = mariadb",
    "DOLI_DB_USER          = dolibarr",
    "DOLI_DB_PASSWORD      = welkom123",
    "DOLI_DB_NAME          = dolibarr",
    "DOLI_ADMIN_LOGIN      = admin",
    "DOLI_ADMIN_PASSWORD   = welkom123",
    "DOLI_URL_ROOT         = http://localhost",
    "PHP_INI_DATE_TIMEZONE = Europe/Amsterdam"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/dolibarr/documents"
    container_path = "/var/www/documents"
  }

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/dolibarr/html/custom"
    container_path = "/var/www/html/custom"
  }

  depends_on = ["docker_container.mariadb"]
}

resource "docker_container" "mariadb" {
  image   = "mariadb:latest"
  name    = "dolibarr-mariadb"
  restart = "unless-stopped"

  env = [
    "MYSQL_USER            = dolibarr",
    "MYSQL_PASSWORD        = welkom123",
    "MYSQL_ROOT_PASSWORD   = welkom123",
    "MYSQL_DATABASE        = dolibarr"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/dolibarr/db"
    container_path = "/var/lib/mysql"
  }


}
