terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "webtop" {
  image = "lscr.io/linuxserver/webtop"
  name  = "webtop"
  ports {
    internal = 3000
    external = 8211
  }
  restart = "unless-stopped"

  env = [
    "PUID       = 1000",
    "PGID       = 1000",
    "TZ         = Europe/Amsterdam",
    "SUBFOLDER  = /",
    "KEYBOARD   = en-us-qwerty",
    "TITLE      = Webtop"
  ]

  privileged   = true
  shm_size     = "1gb"
  devices = [
    "/dev/dri:/dev/dri",
  ]
  security_opt = [
    "seccomp=unconfined",
  ]


  volumes {
    host_path      = "/home/gebruikersnaam/terraform/webtop/config"
    container_path = "/config"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }


}
