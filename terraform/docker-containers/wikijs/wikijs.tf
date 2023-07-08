terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "wiki" {
  image   = "ghcr.io/requarks/wiki:2"
  name    = "wikijs"
  environment = {
    DB_TYPE  = "postgres"
    DB_HOST  = "db"
    DB_PORT  = "5432"
    DB_USER  = "wikijs"
    DB_PASS  = "wikijsrocks"
    DB_NAME  = "wiki"
  }

  ports {
    internal = 3000
    external = 8141
  }

  restart = "unless-stopped"
  depends_on = ["db"]
}

resource "docker_container" "db" {
  image   = "postgres:11-alpine"
  name    = "wikijs-postgres"
  environment = {
    POSTGRES_DB       = "wiki"
    POSTGRES_PASSWORD = "wikijsrocks"
    POSTGRES_USER     = "wikijs"
  }
  logging {
    driver = "none"
  }

  volumes = ["./db:/var/lib/postgresql/data"]

  restart = "unless-stopped"
}
