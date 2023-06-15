# Define the Proxmox provider
provider "proxmox" {
  api_url  = var.proxmox_api_url
  api_token = var.proxmox_api_token
}

# Define the Proxmox full clone resource
resource "proxmox_vm_qemu" "full_clone" {
  name       = var.clone_name
  target_node = var.target_node
  template   = var.template

  full_clone {
    clone_name = var.clone_name
  }

  # Define the virtual machine settings
  memory      = var.memory
  cores       = var.cores
  sockets     = var.sockets
  storage     = var.storage
  disk_size   = var.disk_size
  network_bridge = var.network_bridge
  os_type     = var.os_type

  # Customize additional settings as needed

  # ...
}

# Define the input variables
variable "proxmox_api_url" {
  description = "The URL of the Proxmox API."
  type        = string
}

variable "proxmox_api_token" {
  description = "The Proxmox API token."
  type        = string
}

variable "clone_name" {
  description = "The name of the cloned virtual machine."
  type        = string
}

variable "target_node" {
  description = "The Proxmox node where the clone will be created."
  type        = string
}

variable "template" {
  description = "The name or ID of the template to clone from."
  type        = string
}

variable "memory" {
  description = "The amount of memory for the cloned virtual machine (in MB)."
  type        = number
}

variable "cores" {
  description = "The number of CPU cores for the cloned virtual machine."
  type        = number
}

variable "sockets" {
  description = "The number of CPU sockets for the cloned virtual machine."
  type        = number
}

variable "storage" {
  description = "The storage identifier where the cloned virtual machine's disk will be stored."
  type        = string
}

variable "disk_size" {
  description = "The size of the cloned virtual machine's disk (in GB)."
  type        = number
}

variable "network_bridge" {
  description = "The network bridge to attach the cloned virtual machine to."
  type        = string
}

variable "os_type" {
  description = "The operating system type for the cloned virtual machine."
  type        = string
}
