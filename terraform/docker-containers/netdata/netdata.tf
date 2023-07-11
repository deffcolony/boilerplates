terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "netdata" {
  image = "netdata/netdata"
  name  = "netdata"
  ports {
    internal = 19999
    external = 8166
  }
  cap_add = ["SYS_PTRACE"]
  restart = "unless-stopped"

  security_opt = [
    "apparmor:unconfined"
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/netdata/proc"
    container_path = "/host/proc"
  }

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/netdata/sys"
    container_path = "/host/sys"
  }

  volumes {
    host_path      = "/etc/os-release"
    container_path = "/host/etc/os-release"
  }

  volumes {
    host_path      = "/etc/passwd"
    container_path = "/host/etc/passwd"
  }

  volumes {
    host_path      = "/etc/group"
    container_path = "/host/etc/group"
  }

# ----------Optional----------

#  volumes {
#    host_path      = "/home/gebruikersnaam/terraform/netdata/netdataconfig"
#    container_path = "/etc/netdata"
#  }

#  volumes {
#    host_path      = "/home/gebruikersnaam/terraform/netdata/netdatalib"
#    container_path = "/var/lib/netdata"
#  }

#  volumes {
#    host_path      = "/home/gebruikersnaam/terraform/netdata/netdatacache"
#    container_path = "/var/cache/netdata"
#  }
}
