terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "gitea" {
  image   = "gitea/gitea:latest"
  name    = "gitea"
  environment = {
    USER_UID                 = "1000"
    USER_GID                 = "1000"
    GITEA__database__DB_TYPE = "mysql"
    GITEA__database__HOST    = "gitea-mariadb"
    GITEA__database__NAME    = "gitea"
    GITEA__database__USER    = "gitea"
    GITEA__database__PASSWD  = "gitea"
  }
  volumes = [
    "./data:/data",
    "/etc/timezone:/etc/timezone:ro",
    "/etc/localtime:/etc/localtime:ro",
  ]
  ports {
    internal = 3000
    external = 8223
  }
  ports {
    internal = 22
    external = 8224
  }
  restart = "unless-stopped"
  depends_on = ["db"]
}

resource "docker_container" "db" {
  image   = "mariadb:latest"
  name    = "gitea-mariadb"
  environment = {
    MYSQL_ROOT_PASSWORD = "gitea"
    MYSQL_USER          = "gitea"
    MYSQL_PASSWORD      = "gitea"
    MYSQL_DATABASE      = "gitea"
  }
  volumes = [
    "./db:/var/lib/mysql",
  ]
  restart = "unless-stopped"
}
