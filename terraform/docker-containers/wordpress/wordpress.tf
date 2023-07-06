terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "wordpress" {
  image   = "wordpress"
  name    = "wordpress01"
  volumes = ["./www/YOUREWEBSITENAME:/var/www/html"]

  ports {
    internal = 80
    external = 8170
  }

  restart = "unless-stopped"

  environment = {
    WORDPRESS_DB_HOST     = "db",
    WORDPRESS_DB_USER     = "wordpress",
    WORDPRESS_DB_PASSWORD = "welkom123",
    WORDPRESS_DB_NAME     = "wpdocker",
  }

  depends_on = ["docker_container.db"]
}

resource "docker_container" "db" {
  image   = "mariadb:latest"
  name    = "wordpress01-mariadb"
  volumes = ["./www/db:/var/lib/mysql"]

  restart = "unless-stopped"

  environment = {
    MYSQL_USER          = "wordpress",
    MYSQL_PASSWORD      = "welkom123",
    MYSQL_ROOT_PASSWORD = "welkom123",
    MYSQL_DATABASE      = "wpdocker",
  }
}
