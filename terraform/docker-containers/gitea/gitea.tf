terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "gitea" {
  image   = "gitea/gitea:latest"
  name    = "gitea"
  restart = "unless-stopped"
  ports {
    internal = 3000
    external = 8223
  }
  ports {
    internal = 22
    external = 8224
  }

  env = [
    "USER_UID                 = 1000",
    "USER_GID                 = 1000",
    "GITEA__database__DB_TYPE = mysql",
    "GITEA__database__HOST    = gitea-mariadb",
    "GITEA__database__NAME    = gitea",
    "GITEA__database__USER    = gitea",
    "GITEA__database__PASSWD  = gitea"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitea/data"
    container_path = "/data"
  }

  volumes {
    host_path      = "/etc/timezone"
    container_path = "/etc/timezone"
  }

  volumes {
    host_path      = "/etc/localtime"
    container_path = "/etc/localtime"
  }

  depends_on = ["db"]
}

resource "docker_container" "db" {
  image   = "mariadb:latest"
  name    = "gitea-mariadb"
  restart = "unless-stopped"

  env = [
    "MYSQL_ROOT_PASSWORD = gitea",
    "MYSQL_USER          = gitea",
    "MYSQL_PASSWORD      = gitea",
    "MYSQL_DATABASE      = gitea"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitea/db"
    container_path = "/var/lib/mysql"
  }


}
