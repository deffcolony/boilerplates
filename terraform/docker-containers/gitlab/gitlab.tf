terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_container" "gitlab-runner" {
  image   = "gitlab/gitlab-runner:alpine"
  name    = "gitlab-runner"
  restart = "unless-stopped"

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitlab/gitlab-runner"
    container_path = "/etc/gitlab-runner"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  depends_on = ["web"]
}

resource "docker_container" "web" {
  image   = "gitlab/gitlab-ce:latest"
  name    = "gitlab-ce"
  restart = "unless-stopped"
  ports {
    internal = 80
    external = 8225
  }
  ports {
    internal = 443
    external = 8226
  }
  hostname = "gitlab.example.com"
  env = [
    GITLAB_OMNIBUS_CONFIG = <<EOF
      external_url 'https://gitlab.example.com'
      # Add any other gitlab.rb configuration here, each on its own line
    EOF
  ]

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitlab/config"
    container_path = "/etc/gitlab"
  }

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitlab/logs"
    container_path = "/var/log/gitlab"
  }

  volumes {
    host_path      = "/home/gebruikersnaam/terraform/gitlab/data"
    container_path = "/var/opt/gitlab"
  }


}
