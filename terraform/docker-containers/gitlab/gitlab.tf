terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "gitlab-runner" {
  image   = "gitlab/gitlab-runner:alpine"
  name    = "gitlab-runner"
  volumes = [
    "/var/run/docker.sock:/var/run/docker.sock",
    "./gitlab-runner:/etc/gitlab-runner",
  ]
  restart = "unless-stopped"
  depends_on = ["web"]
}

resource "docker_container" "web" {
  image   = "gitlab/gitlab-ce:latest"
  name    = "gitlab-ce"
  hostname = "gitlab.example.com"
  environment = {
    GITLAB_OMNIBUS_CONFIG = <<EOF
      external_url 'https://gitlab.example.com'
      # Add any other gitlab.rb configuration here, each on its own line
    EOF
  }
  volumes = [
    "./config:/etc/gitlab",
    "./logs:/var/log/gitlab",
    "./data:/var/opt/gitlab",
  ]
  ports {
    internal = 80
    external = 8225
  }
  ports {
    internal = 443
    external = 8226
  }
  restart = "unless-stopped"
}
