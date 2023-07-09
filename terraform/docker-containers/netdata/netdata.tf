terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "netdata" {
  image          = "netdata/netdata"
  container_name = "netdata"

  cap_add = ["SYS_PTRACE"]

  security_opt = [
    "apparmor:unconfined"
  ]

  volumes = [
    "/proc:/host/proc:ro",
    "/sys:/host/sys:ro",
    "/etc/os-release:/host/etc/os-release:ro",
    "/etc/passwd:/host/etc/passwd:ro",
    "/etc/group:/host/etc/group:ro",
    # "./netdataconfig:/etc/netdata", # Optional
    # "./netdatalib:/var/lib/netdata", # Optional
    # "./netdatacache:/var/cache/netdata", # Optional
  ]

  ports {
    internal = 19999
    external = 8166
  }

  restart = "unless-stopped"
}
