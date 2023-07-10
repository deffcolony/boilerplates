terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "wiki" {
  image   = "ghcr.io/requarks/wiki:2"
  name    = "wikijs"
  ports {
    internal = 3000
    external = 8141
  }
  restart = "unless-stopped"

  env = [
    "DB_TYPE  = postgres",
    "DB_HOST  = db",
    "DB_PORT  = 5432",
    "DB_USER  = wikijs",
    "DB_PASS  = wikijsrocks",
    "DB_NAME  = wiki"
  ]

  depends_on = ["db"]
}
 
resource "docker_container" "db" {
  image   = "postgres:11-alpine"
  name    = "wikijs-postgres"

  env = [
    "POSTGRES_DB       = wiki",
    "POSTGRES_PASSWORD = wikijsrocks",
    "POSTGRES_USER     = wikijs"
  ]

  logging {
    driver = "none"
  }
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/wikijs/db"
    container_path = "/var/lib/postgresql/data"
  }


}
