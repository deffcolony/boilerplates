provider "proxmox" {
  pm_tls_insecure         = true
  pm_api_url              = var.proxmox_api_url
  pm_api_username         = var.proxmox_api_username
  pm_api_password         = var.proxmox_api_password
  pm_api_token            = var.proxmox_api_token
  pm_api_token_name       = var.proxmox_api_token_name
  pm_api_token_secret     = var.proxmox_api_token_secret
  pm_default_node         = var.proxmox_default_node
  pm_ssh_config_file      = var.proxmox_ssh_config_file
  pm_ssh_private_key_file = var.proxmox_ssh_private_key_file
  pm_ssh_proxy_jump       = var.proxmox_ssh_proxy_jump
}
