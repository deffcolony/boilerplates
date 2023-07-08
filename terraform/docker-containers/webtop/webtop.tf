terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "webtop" {
  image          = "lscr.io/linuxserver/webtop"
  container_name = "webtop"
  privileged     = true
  shm_size       = "1gb"
  devices = [
    "/dev/dri:/dev/dri",
  ]
  security_opt = [
    "seccomp=unconfined",
  ]
  environment = {
    PUID      = "1000"
    PGID      = "1000"
    TZ        = "Europe/Amsterdam"
    SUBFOLDER = "/"
    KEYBOARD  = "en-us-qwerty"
    TITLE     = "Webtop"
  }
  volumes = [
    "./config:/config",
    "/var/run/docker.sock:/var/run/docker.sock",
  ]
  ports {
    internal = 3000
    external = 8211
  }
  restart = "unless-stopped"
}
