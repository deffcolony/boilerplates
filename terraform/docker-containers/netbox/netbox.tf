terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "netbox" {
  image   = "lscr.io/linuxserver/netbox:latest"
  name    = "netbox"
  ports {
    internal = 8000
    external = 9140
  }
  restart = "unless-stopped"

  env = [
    "PUID                           = 1000",
    "PGID                           = 1000",
    "SKIP_SUPERUSER                 = false",
    "SUPERUSER_NAME                 = admin",
    "SUPERUSER_EMAIL                = info@mydomain.com",
    "SUPERUSER_PASSWORD             = M3D8B4C7Q1b9c5z6",
    "ALLOWED_HOST                   = netbox.mydomain.com",
    "DB_NAME                        = netbox",
    "DB_USER                        = netbox",
    "DB_PASSWORD                    = U8C4S2K0L4c6n3s1l0",
    "DB_HOST                        = db",
    "DB_PORT                        = 5432",
    "REDIS_HOST                     = redis",
    "REDIS_PORT                     = 6379",
    "REDIS_PASSWORD                 = q7v9x3V0z5c4n1R0B1X6",
    "REDIS_DB_TASK                  = 0",
    "REDIS_DB_CACHE                 = 1",
#    "BASE_PATH                      = "",
#    "REMOTE_AUTH_ENABLED            = "",
#    "REMOTE_AUTH_BACKEND            = "",
#    "REMOTE_AUTH_HEADER             = "",
#    "REMOTE_AUTH_AUTO_CREATE_USER   = "",
#    "REMOTE_AUTH_DEFAULT_GROUPS     = "",
#    "REMOTE_AUTH_DEFAULT_PERMISSIONS = "",
    "WEBHOOKS_ENABLED               = true"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/netbox/config"
    container_path = "/config"
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

resource "docker_container" "db" {
  image   = "postgres:latest"
  name    = "netbox-postgres"
  restart = "unless-stopped"

  env = [
    "POSTGRES_DB       = netbox",
    "POSTGRES_USER     = netbox",
    "POSTGRES_PASSWORD = U8C4S2K0L4c6n3s1l0"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/netbox/db"
    container_path = "/var/lib/postgresql/data"
  }


}

resource "docker_container" "redis" {
  image   = "redis:latest"
  name    = "netbox-redis"
  command = "redis-server --requirepass q7v9x3V0z5c4n1R0B1X6"
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/netbox/redis"
    container_path = "/data"
  }


}
