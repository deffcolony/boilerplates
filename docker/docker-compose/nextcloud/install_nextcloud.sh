#!/bin/bash
set -euo pipefail

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

# Configurations
REMOTEIP_CONF="./remoteip.conf"
CRON_SCRIPT="./cron.sh"
ENV_FILE="./.env"
SERVICE_ACCOUNT="svc_nextcloud_docker"

# Functions
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
NEXTCLOUD_FQDN=nextcloud.DOMAIN.COM
NEXTCLOUD_TRUSTED_DOMAINS=nextcloud.DOMAIN.COM
OVERWRITEHOST=nextcloud.DOMAIN.COM
overwrite.cli.url=https://nextcloud.DOMAIN.COM
OVERWRITEPROTOCOL=https
TRUSTED_PROXIES=172.16.0.0/12 192.168.0.0/16 10.0.0.0/8 fc00::/7 fe80::/10 2001:db8::/32

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
    log_message "INFO" "Permissions set."
}

setup_containers() {
    log_message "INFO" "Setting up nextcloud docker containers..."
    docker compose up -d
}

setup_notify_push() {
    log_message "INFO" "Setting up notify_push..."
    docker compose exec app php occ app:install notify_push
    docker compose up -d notify_push
    docker compose exec app sh -c "php occ notify_push:setup https://${OVERWRITEHOST}/push"
    log_message "INFO" "notify_push configured."
}

check_notify_push_stats() {
    log_message "INFO" "Checking notify_push stats..."
    docker compose exec app php occ notify_push:metrics
    docker compose exec app php occ notify_push:self-test
    log_message "INFO" "notify_push stats checked."
}

configure_system_settings() {
    log_message "INFO" "Configuring system settings..."
    docker compose exec app php occ background:Cron
    docker compose exec app php occ config:system:set maintenance_window_start --type=integer --value=1
    docker compose exec app php occ config:system:set default_phone_region --value='CH'
    log_message "INFO" "System settings configured."
}

setup_imaginary() {
    log_message "INFO" "Setting up Imaginary..."
    docker compose exec app php occ config:system:get enabledPreviewProviders
    docker compose exec app php occ config:system:set enabledPreviewProviders 0 --value 'OC\\Preview\\MP3'
    docker compose exec app php occ config:system:set enabledPreviewProviders 1 --value 'OC\\Preview\\TXT'
    docker compose exec app php occ config:system:set enabledPreviewProviders 2 --value 'OC\\Preview\\MarkDown'
    docker compose exec app php occ config:system:set enabledPreviewProviders 3 --value 'OC\\Preview\\OpenDocument'
    docker compose exec app php occ config:system:set enabledPreviewProviders 4 --value 'OC\\Preview\\Krita'
    docker compose exec app php occ config:system:set enabledPreviewProviders 5 --value 'OC\\Preview\\Imaginary'
    docker compose exec app php occ config:system:set preview_imaginary_url --value 'http://imaginary:9000'
    log_message "INFO" "Imaginary configured."
}

limit_parallel_jobs() {
    log_message "INFO" "Limiting parallel jobs..."
    docker compose exec app php occ config:system:set preview_concurrency_all --value 12
    docker compose exec app php occ config:system:set preview_concurrency_new --value 8
    log_message "INFO" "Parallel jobs limited."
}

install_apps() {
    log_message "INFO" "Installing apps..."
    local apps=(
        "user_oidc"
        "groupfolders"
        "twofactor_webauthn"
        "polls"
        "memories"
        "cfg_share_links"
        "theming_customcss"
    )
    for app in "${apps[@]}"; do
        log_message "INFO" "Installing $app..."
        docker compose exec app php occ app:install "$app"
    done
    log_message "INFO" "Apps installed."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "This script must be run as root."
    exit 1
fi

# Main Execution
log_message "INFO" "Starting Nextcloud setup..."
configure_remoteip
configure_cron
configure_env
setup_service_account
setup_permissions
setup_containers
setup_notify_push
check_notify_push_stats
configure_system_settings
setup_imaginary
limit_parallel_jobs
install_apps

log_message "INFO" "Nextcloud setup completed!"
