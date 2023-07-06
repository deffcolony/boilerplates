terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "netbox" {
  image   = "lscr.io/linuxserver/netbox:latest"
  name    = "netbox"
  volumes = [
    "./config:/config",
    "/etc/timezone:/etc/timezone:ro",
    "/etc/localtime:/etc/localtime:ro",
  ]

  ports {
    internal = 8000
    external = 9140
  }

  restart = "unless-stopped"

  environment = {
    PUID                           = "1000",
    PGID                           = "1000",
    SKIP_SUPERUSER                 = "false",
    SUPERUSER_NAME                 = "admin",
    SUPERUSER_EMAIL                = "info@mydomain.com",
    SUPERUSER_PASSWORD             = "M3D8B4C7Q1b9c5z6",
    ALLOWED_HOST                   = "netbox.mydomain.com",
    DB_NAME                        = "netbox",
    DB_USER                        = "netbox",
    DB_PASSWORD                    = "U8C4S2K0L4c6n3s1l0",
    DB_HOST                        = "db",
    DB_PORT                        = "5432",
    REDIS_HOST                     = "redis",
    REDIS_PORT                     = "6379",
    REDIS_PASSWORD                 = "q7v9x3V0z5c4n1R0B1X6",
    REDIS_DB_TASK                  = "0",
    REDIS_DB_CACHE                 = "1",
    BASE_PATH                      = "",
    REMOTE_AUTH_ENABLED            = "",
    REMOTE_AUTH_BACKEND            = "",
    REMOTE_AUTH_HEADER             = "",
    REMOTE_AUTH_AUTO_CREATE_USER   = "",
    REMOTE_AUTH_DEFAULT_GROUPS     = "",
    REMOTE_AUTH_DEFAULT_PERMISSIONS = "",
    WEBHOOKS_ENABLED               = "true",
  }
}

resource "docker_container" "db" {
  image   = "postgres:latest"
  name    = "netbox-postgres"
  volumes = ["./db:/var/lib/postgresql/data"]

  restart = "unless-stopped"

  environment = {
    POSTGRES_DB       = "netbox",
    POSTGRES_USER     = "netbox",
    POSTGRES_PASSWORD = "U8C4S2K0L4c6n3s1l0",
  }
}

resource "docker_container" "redis" {
  image   = "redis:latest"
  name    = "netbox-redis"
  command = "redis-server --requirepass q7v9x3V0z5c4n1R0B1X6"
  volumes = ["./redis:/data"]

  restart = "unless-stopped"
}
