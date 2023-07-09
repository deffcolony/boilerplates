packer {
  required_plugins {
    vsphere = {
      version = ">= 0.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

source "vsphere-iso" "ubuntu" {
  iso_url           = "https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso"
  iso_checksum      = "sha256:1234567890"
  iso_checksum_type = "sha256"
  boot_command = [
    "<enter><f6><esc><wait>",
    "<esc><wait>",
    "/install/vmlinuz",
    "initrd=/install/initrd.gz",
    "auto-install/enable=true",
    "debconf/priority=critical",
    "console-setup/ask_detect=false",
    "console-setup/layoutcode=us",
    "console-setup/variantcode=us",
    "netcfg/get_hostname={{ .Name }}",
    "netcfg/get_domain={{ .Name }}",
    "netcfg/disable_autoconfig=true",
    "netcfg/choose_interface=auto",
    "netcfg/dhcp_timeout=60",
    "netcfg/get_ipaddress=192.168.1.55",    # CHANGEME!!!
    "netcfg/get_netmask=255.255.255.0",     # CHANGEME!!!
    "netcfg/get_gateway=192.168.1.1",       # CHANGEME!!!
    "netcfg/get_nameservers=1.1.1.1",       # CHANGEME!!!
    "netcfg/confirm_static=true",
    "netcfg/get_hostname=ubuntu",           # CHANGEME!!!
    "<enter>"
  ]
  boot_wait            = "10s"
  shutdown_command     = "echo 'packer' | sudo -S shutdown -P now"
  ssh_username         = "packer"
  ssh_password         = "packer"
  shutdown_timeout     = "10m"
  guest_additions_mode = "disable_shared_folders"
  format               = "ova"
  output_directory     = "output-vmware-iso"
}

build {
  sources = ["vsphere-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y ssh neofetch net-tools netdiscover ncdu duf",
      "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config",
      "timedatectl set-timezone Europe/Amsterdam",  # CHANGEME!!!
      "cat <<EOF > /etc/netplan/00-installer-config.yaml",
      "network:",
      "  version: 2",
      "  renderer: networkd",
      "  ethernets:",
      "    ens33:",
      "      addresses: [ \"192.168.1.55/24\" ]",   # CHANGEME!!!
      "      nameservers:",
      "        addresses: [1.1.1.1]",               # CHANGEME!!!
      "      routes:",
      "       - to: 0.0.0.0/0",
      "         via: 192.168.1.1",                  # CHANGEME!!!
      "         on-link: true",
      "EOF",
      "sudo parted resizepart /dev/sda 2 100%",
      "sudo resize2fs /dev/sda2"
    ]
  }

  post-processor "vsphere-template" {
    keep_registered = false
    cluster         = "my-cluster"
    folder          = "my-folder"
    datastore       = "my-datastore"
    vm_name         = "ubuntu-server-jammy"
  }
}
