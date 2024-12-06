#!/bin/bash
set -euo pipefail

# Config variables
DOMAIN="nextcloud.domain.com"
COLLABORA_DOMAIN="collabora.domain.com"
OVERWRITEHOST=${DOMAIN}
SERVICE_ACCOUNT="svc_nextcloud_docker"


# script config
REMOTEIP_CONF="./remoteip.conf"
CRON_SCRIPT="./cron.sh"
ENV_FILE="./.env"

# ANSI Escape Code for Colors
reset="\033[0m"
white_fg_strong="\033[90m"
red_fg_strong="\033[91m"
green_fg_strong="\033[92m"
yellow_fg_strong="\033[93m"
blue_fg_strong="\033[94m"
magenta_fg_strong="\033[95m"
cyan_fg_strong="\033[96m"

# Text styles
bold="\033[1m"

# Normal Background Colors
red_bg="\033[41m"
blue_bg="\033[44m"
yellow_bg="\033[43m"

# Foreground colors
yellow_fg_strong="\033[33;1m"

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


# Ensure root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "This script must be run as root."
        exit 1
    fi
}

# Installation function
install_nextcloud() {
    log_message "INFO" "Starting Nextcloud installation..."

    configure_remoteip
    configure_cron
    configure_env
    setup_service_account
    setup_permissions
    setup_containers || log_message "WARN" "nextcloud_push failed to start. This is normal. Continuing with configuration."
    # nextcloud_push container will fail to start which is normal. Do not stop the script.

    wait_for_app_ready
    setup_notify_push || log_message "WARN" "failed to setup Client Push."
    check_notify_push_stats || log_message "INFO" "Continuing..."
    configure_system_settings
    setup_imaginary
    limit_parallel_jobs
    install_apps
    setup_richdocuments

    # Completion message
    log_message "INFO" "Nextcloud installed and configured successfully."
    echo -e "\n${bold}Next Steps:${reset}"
    echo -e "- Ensure your reverse proxy or custom networking settings are properly configured."
    echo -e "- Once done, you can visit your Nextcloud server at: ${yellow_fg_strong}https://${DOMAIN}${reset}"

    # Return to home menu
    read -p "Press Enter to return home..."
    home
}

# Configuration function
configure_nextcloud() {

    # Return to home menu
    echo -e "Coming soon... edit what apps will be installed, edit domains and more"
    read -p "Press Enter to return home..."
    home

}


# Function to display Danger Zone warning
display_danger_zone_warning() {
    echo
    echo -e "${red_bg}${bold}╔════ DANGER ZONE ═══════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_bg}${bold}║ WARNING: This action will PERMANENTLY DELETE all data related to Nextcloud!        ║${reset}"
    echo -e "${red_bg}${bold}║ Ensure you have created backups if you want to retain any information.             ║${reset}"
    echo -e "${red_bg}${bold}║ This includes files, databases, configurations, and Docker containers.             ║${reset}"
    echo -e "${red_bg}${bold}╚════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo
}

# Function to uninstall Nextcloud
uninstall_nextcloud() {
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirmation

    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Proceeding with uninstallation..."

        # Ensure the script is run as root
        if [[ $EUID -ne 0 ]]; then
            log_message "ERROR" "This script must be run as root."
            exit 1
        fi

        # Remove Docker Containers, Volumes, and Network for Nextcloud
        log_message "INFO" "Stopping and removing Nextcloud containers, volumes, and network..."
        docker compose down --volumes --remove-orphans || log_message "WARN" "Docker compose down encountered issues. Continuing cleanup."

        # Remove Nextcloud Data
        log_message "INFO" "Deleting Nextcloud data..."
        rm -rf nextcloud apps data db || log_message "WARN" "Failed to remove some data directories."

        # Remove configuration files and other related directories
        log_message "INFO" "Removing configuration files..."
        rm -rf config .env cron.sh redis-session.ini remoteip.conf || log_message "WARN" "Failed to remove some configuration files."

        # Remove Service Account
        log_message "INFO" "Removing Service Account $SERVICE_ACCOUNT..."
        if id "$SERVICE_ACCOUNT" &>/dev/null; then
            sudo userdel -r "$SERVICE_ACCOUNT" || log_message "WARN" "Failed to remove service account $SERVICE_ACCOUNT."
        else
            log_message "INFO" "Service account $SERVICE_ACCOUNT does not exist."
        fi

        # Final message
        log_message "INFO" "Nextcloud uninstalled successfully."
        read -p "Press Enter to continue..."
        home
    else
        log_message "INFO" "Uninstallation canceled. No changes were made."
        read -p "Press Enter to continue..."
        home
    fi
}



############################
#   INSTALL NEXTCLOUD      #
############################
configure_remoteip() {
    log_message "INFO" "Configuring remoteip.conf..."
    cat > $REMOTEIP_CONF << EOF
RemoteIPHeader X-Real-Ip
RemoteIPInternalProxy 10.0.0.0/8
RemoteIPInternalProxy 172.16.0.0/12
RemoteIPInternalProxy 192.168.0.0/16
RemoteIPInternalProxy fc00::/7
RemoteIPInternalProxy fe80::/10
RemoteIPInternalProxy 2001:db8::/32
EOF
    log_message "INFO" "remoteip.conf configured."
}

configure_cron() {
    log_message "INFO" "Configuring cron.sh..."
    cat > $CRON_SCRIPT << EOF
#!/bin/sh
set -eu
adduser --disabled-password --gecos "" --no-create-home --uid 1004 cron
mv /var/spool/cron/crontabs/www-data /var/spool/cron/crontabs/cron
exec busybox crond -f -L /dev/stdout
EOF
    chmod +x $CRON_SCRIPT
    log_message "INFO" "cron.sh configured."
}

configure_env() {
    log_message "INFO" "Configuring .env..."
    cat > $ENV_FILE << EOF
# General Nextcloud Configuration
TIMEZONE=Etc/UTC
NEXTCLOUD_FQDN=${DOMAIN}
NEXTCLOUD_TRUSTED_DOMAINS=${DOMAIN}
OVERWRITEHOST=${DOMAIN}
overwrite.cli.url=https://${DOMAIN}
OVERWRITEPROTOCOL=https
TRUSTED_PROXIES=172.16.0.0/12 192.168.0.0/16 10.0.0.0/8 fc00::/7 fe80::/10 2001:db8::/32

# Collabora
COLLABORA_FQDN=${COLLABORA_DOMAIN}
COLLABORA_DOMAINS=${DOMAIN}

# PHP Configuration
PHP_MEMORY_LIMIT=1G
PHP_UPLOAD_LIMIT=10G

# Database Configuration
POSTGRES_HOST=db
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=nextcloud!

# Admin User Credentials
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=admin

# Redis Configuration
REDIS_HOST=redis

# Permissions for Service account: svc_nextcloud_docker
UID=1004
GID=1004
EOF
    log_message "INFO" ".env configured."
}

setup_service_account() {
    log_message "INFO" "Setting up service account..."
    sudo useradd --no-create-home $SERVICE_ACCOUNT --shell /usr/sbin/nologin --uid 1004
    log_message "INFO" "Service account $SERVICE_ACCOUNT created."
}

setup_permissions() {
    log_message "INFO" "Setting up mount points and permissions..."
    mkdir -p apps config data nextcloud db
    touch redis-session.ini
    sudo chown -R 1004:1004 apps config data nextcloud db redis-session.ini $CRON_SCRIPT
    sudo chmod +x cron.sh
}

setup_containers() {
    log_message "INFO" "Setting up Nextcloud Docker containers..."
    docker compose up -d
}


# Wait for the container logs to show "Initializing finished"
wait_for_app_ready() {
    local container_name="nextcloud"
    local max_attempts=30 # Maximum number of log checks
    local attempt=1

    log_message "INFO" "Waiting for container logs to show 'Initializing finished'..."

    while [[ $attempt -le $max_attempts ]]; do
        # Fetch logs and check for the desired phrase
        if docker logs "$container_name" 2>&1 | grep -q "Initializing finished"; then
            log_message "INFO" "'Initializing finished' detected in logs. Proceeding..."
            setup_notify_push
            return
        fi

        log_message "WARN" "Attempt $attempt/$max_attempts: 'Initializing finished' not detected yet. Retrying in 10 seconds..."
        sleep 10
        attempt=$((attempt + 1))
    done

    log_message "ERROR" "Unable to detect 'Initializing finished' in logs after $max_attempts attempts."
    read -p "Press Enter to uninstall nextcloud and retry..."
    uninstall_nextcloud
}

############################
#   CONFIGURE NEXTCLOUD    #
############################
setup_notify_push() {
    log_message "INFO" "Setting up notify_push..."
    docker compose exec app php occ app:install notify_push
    docker compose up -d notify_push
#    docker compose exec app sh -c "php occ notify_push:setup https://${OVERWRITEHOST}/push" #TODO FIX PUSH SERVER
}

check_notify_push_stats() {
    log_message "INFO" "Checking notify_push stats..."
    docker compose exec app php occ notify_push:metrics
    docker compose exec app php occ notify_push:self-test
}

configure_system_settings() {
    log_message "INFO" "Configuring system settings..."
    docker compose exec app php occ background:cron
    docker compose exec app php occ db:add-missing-indices
    docker compose exec app php occ maintenance:repair --include-expensive
    docker compose exec app php occ config:system:set maintenance_window_start --type=integer --value=1
    docker compose exec app php occ config:system:set default_phone_region --value='US' # Valid regions here https://en.wikipedia.org/wiki/ISO_3166-1
}

setup_imaginary() {
    log_message "INFO" "Setting up Imaginary..."
#    docker compose exec app php occ config:system:get enabledPreviewProviders
    docker compose exec app php occ config:system:set enabledPreviewProviders 0 --value 'OC\\Preview\\MP3'
    docker compose exec app php occ config:system:set enabledPreviewProviders 1 --value 'OC\\Preview\\TXT'
    docker compose exec app php occ config:system:set enabledPreviewProviders 2 --value 'OC\\Preview\\MarkDown'
    docker compose exec app php occ config:system:set enabledPreviewProviders 3 --value 'OC\\Preview\\OpenDocument'
    docker compose exec app php occ config:system:set enabledPreviewProviders 4 --value 'OC\\Preview\\Krita'
    docker compose exec app php occ config:system:set enabledPreviewProviders 5 --value 'OC\\Preview\\Imaginary'
    docker compose exec app php occ config:system:set preview_imaginary_url --value 'http://imaginary:9000'
}

limit_parallel_jobs() {
    log_message "INFO" "Limiting parallel jobs..."
    docker compose exec app php occ config:system:set preview_concurrency_all --value 12
    docker compose exec app php occ config:system:set preview_concurrency_new --value 8
}

install_apps() {
    log_message "INFO" "Installing apps..."
    local apps=(
        "user_oidc"
        "groupfolders"
        "twofactor_webauthn"
        "polls"
#        "memories" # optional
        "cfg_share_links"
        "theming_customcss"
    )
    for app in "${apps[@]}"; do
        log_message "INFO" "Installing $app..."
        docker compose exec app php occ app:install "$app"
    done
    log_message "INFO" "Apps installed."
}


setup_richdocuments() {
    log_message "INFO" "Setting up RichDocuments..."
    docker compose exec app php occ app:install richdocuments
    # uncomment below to use wopi_allowlist if emty then allow all hosts
    docker compose exec app php occ config:app:set richdocuments wopi_allowlist --value "0.0.0.0/0"
    docker compose exec app php occ config:app:set richdocuments wopi_url --value https://${COLLABORA_DOMAIN}
    docker compose exec app php occ richdocuments:activate-config
    docker compose exec app php occ config:system:set skeletondirectory --value="" --type=string # emty value disables the demo/placeholder files
}

# Menu function
home() {
    clear
    echo -e "\033]0;Nextcloud [HOME]\007"
    echo -e "${blue_fg_strong}/ Home${reset}"
    echo "-------------------------------------"
    echo "What would you like to do?"
    echo "1. Install Nextcloud"
    echo "2. Configure Nextcloud"
    echo "3. UNINSTALL Nextcloud"
    echo "0. Exit"
    read -p "Choose Your Destiny (default is 1): " choice

    # Default to choice 1 if no input
    choice=${choice:-1}
    case $choice in
        1) install_nextcloud ;;
        2) configure_nextcloud ;;
        3) uninstall_nextcloud ;;
        0) exit ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            home ;;
    esac
}

# Ensure root privileges before starting
check_root

# Start the menu
home