#!/bin/bash
# Script to configure an Ubuntu server

# ANSI Escape Code for Colors
reset="\033[0m"
white_fg_strong="\033[90m"
red_fg_strong="\033[91m"
green_fg_strong="\033[92m"
yellow_fg_strong="\033[93m"
blue_fg_strong="\033[94m"
magenta_fg_strong="\033[95m"
cyan_fg_strong="\033[96m"

# Normal Background Colors
red_bg="\033[41m"
blue_bg="\033[44m"
yellow_bg="\033[43m"


# Variables (Edit these as needed)
STATIC_IP="192.168.1.55/24"
GATEWAY="192.168.1.2"
DNS_SERVERS="1.1.1.1,1.0.0.1"
TIMEZONE="Europe/Amsterdam"
PRIMARY_INTERFACE=""

# Function to log messages with timestamps and colors
log_message() {
    current_time=$(date +'%H:%M:%S') # Current time
    case "$1" in
        "INFO")
            echo -e "${blue_bg}[$current_time]${reset} ${blue_fg_strong}[INFO]${reset} $2"
            ;;
        "WARN")
            echo -e "${yellow_bg}[$current_time]${reset} ${yellow_fg_strong}[WARN]${reset} $2"
            ;;
        "ERROR")
            echo -e "${red_bg}[$current_time]${reset} ${red_fg_strong}[ERROR]${reset} $2"
            ;;
        *)
            echo -e "${blue_bg}[$current_time]${reset} ${blue_fg_strong}[DEBUG]${reset} $2"
            ;;
    esac
}

# Function to detect the primary network interface
detect_network_interface() {
    log_message "INFO" "Detecting the primary network interface..."
    PRIMARY_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
    if [[ -z "$PRIMARY_INTERFACE" ]]; then
        log_message "ERROR" "Could not detect the primary network interface."
        exit 1
    fi
    log_message "INFO" "Detected network interface: $PRIMARY_INTERFACE"
}

# Set up SSH to allow root login
configure_ssh() {
    log_message "INFO" "Configuring SSH to allow root login..."
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    log_message "INFO" "SSH configuration updated and service restarted."
}

# Update and upgrade the system
update_system() {
    log_message "INFO" "Updating the system..."
    apt update -y && apt full-upgrade -y && apt autoremove -y
    log_message "INFO" "System updated and upgraded successfully."
}

# Set the timezone
configure_timezone() {
    log_message "INFO" "Setting timezone to $TIMEZONE..."
    timedatectl set-timezone "$TIMEZONE"
    log_message "INFO" "Timezone set to: $(timedatectl)"
}

# Disable cloud-init network configuration
disable_cloud_init() {
    log_message "INFO" "Disabling cloud-init network configuration..."
    mkdir -p /etc/cloud/cloud.cfg.d
    echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    rm -rf /etc/netplan/50-cloud-init.yaml
    netplan apply
    log_message "INFO" "Cloud-init network configuration disabled."
}

# Configure netplan for static IP
configure_netplan() {
    log_message "INFO" "Configuring static IP for interface $PRIMARY_INTERFACE..."
    cat <<EOF >/etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $PRIMARY_INTERFACE:
      dhcp4: no
      dhcp6: no
      addresses:
        - "$STATIC_IP"
      nameservers:
        addresses: [$DNS_SERVERS]
      routes:
        - to: default
          via: "$GATEWAY"
          on-link: true
      wakeonlan: true
EOF
    chmod 600 /etc/netplan/00-installer-config.yaml
    netplan apply
    log_message "INFO" "Static IP configuration applied for $PRIMARY_INTERFACE."
}

# Install useful packages
install_packages() {
    log_message "INFO" "Installing useful packages..."
    apt install -y net-tools jq curl ethtool netdiscover ncdu duf vifm btop
    log_message "INFO" "Useful packages installed successfully."
}

# Install Docker
install_docker() {
    log_message "INFO" "Installing Docker..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    log_message "INFO" "Docker installed successfully."
}

# Install Docker Compose
install_docker_compose() {
    log_message "INFO" "Installing Docker Compose..."
    apt install -y jq
    DOCKER_COMPOSE_VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)
    DOCKER_CLI_PLUGIN_PATH=/usr/local/lib/docker/cli-plugins
    mkdir -p "$DOCKER_CLI_PLUGIN_PATH"
    curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
        -o "$DOCKER_CLI_PLUGIN_PATH/docker-compose"
    chmod +x "$DOCKER_CLI_PLUGIN_PATH/docker-compose"
    log_message "INFO" "Docker Compose installed successfully."
}

# LVM Fix
fix_lvm() {
    log_message "INFO" "Expanding LVM partition..."
    sudo lvm lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
    sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
    log_message "INFO" "LVM partition expanded successfully."
}

# Configure Wake-on-LAN
configure_wol() {
    log_message "INFO" "Enabling Wake-on-LAN for $PRIMARY_INTERFACE..."
    sudo ethtool -s "$PRIMARY_INTERFACE" wol g

    # Create Wake-on-LAN systemd service
    log_message "INFO" "Creating systemd service for Wake-on-LAN..."
    sudo bash -c "cat > /etc/systemd/system/wol.service" <<EOF
[Unit]
Description=Enable Wake On Lan
[Service]
Type=oneshot
ExecStart=/sbin/ethtool --change $PRIMARY_INTERFACE wol g
[Install]
WantedBy=basic.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable wol.service
    log_message "INFO" "Wake-on-LAN configured and service created."
}

# Main script execution
main() {
    log_message "INFO" "Starting setup script..."

    # Run all configuration steps
    detect_network_interface
    configure_ssh
    update_system
    configure_timezone
    disable_cloud_init
    configure_netplan
    install_packages
    install_docker
    install_docker_compose
    fix_lvm
    configure_wol

    log_message "INFO" "Setup complete! Please reboot the server to ensure all changes take effect."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "This script must be run as root."
    exit 1
fi

# Execute the main function
main
