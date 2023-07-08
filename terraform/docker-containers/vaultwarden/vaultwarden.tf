terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "vaultwarden" {
  image          = "vaultwarden/server:latest"
  container_name = "vaultwarden"
  environment = {
    DOMAIN                        = "https://subdomain.yourdomain.com"
    LOGIN_RATELIMIT_MAX_BURST     = "10"
    LOGIN_RATELIMIT_SECONDS       = "60"
    ADMIN_RATELIMIT_MAX_BURST     = "10"
    ADMIN_RATELIMIT_SECONDS       = "60"
    ADMIN_TOKEN                   = "YourReallyStrongAdminTokenHere"
    SENDS_ALLOWED                 = "true"
    EMERGENCY_ACCESS_ALLOWED      = "true"
    WEB_VAULT_ENABLED             = "true"
    SIGNUPS_ALLOWED               = "false"
    SIGNUPS_VERIFY                = "true"
    SIGNUPS_VERIFY_RESEND_TIME    = "3600"
    SIGNUPS_VERIFY_RESEND_LIMIT   = "5"
    SIGNUPS_DOMAINS_WHITELIST     = "yourdomainhere.lan,anotherdomain.lan"
    SMTP_HOST                     = "smtp.youremaildomain.com"
    SMTP_FROM                     = "vaultwarden@youremaildomain.com"
    SMTP_FROM_NAME                = "Vaultwarden"
    SMTP_SECURITY                 = "starttls" # Possible values: “starttls” / “force_tls” / “off”
    SMTP_PORT                     = "XXXX" # Possible values: 587 / 465
    SMTP_USERNAME                 = "vaultwarden@youremaildomain.com"
    SMTP_PASSWORD                 = "YourReallyStrongPasswordHere"
    SMTP_AUTH_MECHANISM           = "Plain" # Possible values: “Plain” / “Login” / “Xoauth2”
  }
  volumes = [
    "./data/:/data/",
  ]
  ports {
    internal = 80
    external = 9200
  }
  restart = "unless-stopped"
}
