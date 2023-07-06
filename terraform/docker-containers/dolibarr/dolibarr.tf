terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "dolibarr" {
  image   = "tuxgasy/dolibarr"
  name    = "dolibarr"
  volumes = [
    "./documents:/var/www/documents",
    "./html/custom:/var/www/html/custom",
  ]
  ports {
    internal = 80
    external = 8200
  }

  restart = "unless-stopped"
  depends_on = ["docker_container.mariadb"]

  environment = {
    DOLI_DB_HOST          = "mariadb"
    DOLI_DB_USER          = "dolibarr"
    DOLI_DB_PASSWORD      = "welkom123"
    DOLI_DB_NAME          = "dolibarr"
    DOLI_ADMIN_LOGIN      = "admin"
    DOLI_ADMIN_PASSWORD   = "welkom123"
    DOLI_URL_ROOT         = "http://localhost"
    PHP_INI_DATE_TIMEZONE = "Europe/Amsterdam"
  }
}

resource "docker_container" "mariadb" {
  image   = "mariadb:latest"
  name    = "dolibarr-mariadb"
  volumes = ["./db:/var/lib/mysql"]

  restart = "unless-stopped"

  environment = {
    MYSQL_USER            = "dolibarr"
    MYSQL_PASSWORD        = "welkom123"
    MYSQL_ROOT_PASSWORD   = "welkom123"
    MYSQL_DATABASE        = "dolibarr"
  }
}
