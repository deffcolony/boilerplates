terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "wordpress" {
  image = "wordpress"
  name  = "wordpress01"
  ports {
    internal = 80
    external = 8170
  }
  restart = "unless-stopped"

  env = [
    "WORDPRESS_DB_HOST     = db",
    "WORDPRESS_DB_USER     = wordpress",
    "WORDPRESS_DB_PASSWORD = welkom123",
    "WORDPRESS_DB_NAME     = wpdocker"
  ]


  volumes {
    host_path      = "/home/gebruikersnaam/terraform/wordpress/www/YOUREWEBSITENAME"
    container_path = "/var/www/html"
  }

  depends_on = [docker_container.db]
}

resource "docker_container" "db" {
  image = "mariadb:latest"
  name  = "wordpress01-mariadb"
  restart = "unless-stopped"

  env = [
    "MYSQL_USER           = wordpress",
    "MYSQL_PASSWORD       = welkom123",
    "MYSQL_ROOT_PASSWORD  = welkom123",
    "MYSQL_DATABASE       = wpdocker"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/wordpress/www/db"
    container_path = "/var/lib/mysql"
  }


}
