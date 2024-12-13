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

########################################################################################
########################################################################################
####################### HOME MENU FUNCTIONS  ###########################################
########################################################################################
########################################################################################

# Exit Function
exit_program() {
    clear
    echo "Bye!"
    exit 0
}

# Function to rescan files in Nextcloud
rescan_files() {
    log_message "INFO" "Starting file rescan for Nextcloud..."
    sudo chown -R "$SERVICE_ACCOUNT":"$SERVICE_ACCOUNT" ./data
    docker compose exec app php occ files:scan --all
    read -p "Press Enter to continue..."
    home
}


install_nextcloud() {

    # Check if the Nextcloud container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^nextcloud$"; then
        log_message "WARN" "Nextcloud is already installed!"
        read -p "Press Enter to return home"
        home
        return
    fi

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
    configure_system
    configure_email
    configure_imaginary
    limit_parallel_jobs
    install_apps
    install_richdocuments

    # Completion message
    log_message "INFO" "Nextcloud installed and configured successfully."
    echo -e "\n${bold}Next Steps:${reset}"
    echo -e "- Ensure your reverse proxy or custom networking settings are properly configured."
    echo -e "- Once done, you can visit your Nextcloud server at: ${yellow_fg_strong}https://${DOMAIN}${reset}"

    # Return to home menu
    read -p "Press Enter to return home..."
    home
}


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
    # Does the service account already exist?
    if id "$SERVICE_ACCOUNT" &>/dev/null; then
        log_message "INFO" "Service account $SERVICE_ACCOUNT already exists."
        return
    fi
    sudo useradd --no-create-home "$SERVICE_ACCOUNT" --shell /usr/sbin/nologin --uid 1004
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
    docker compose exec app sh -c "php occ notify_push:setup https://${OVERWRITEHOST}/push"
}

check_notify_push_stats() {
    log_message "INFO" "Checking notify_push stats..."
    docker compose exec app php occ notify_push:metrics
    docker compose exec app php occ notify_push:self-test
}

configure_system() {
    log_message "INFO" "Configuring system settings..."
    docker compose exec app php occ background:cron
    docker compose exec app php occ db:add-missing-indices
    docker compose exec app php occ maintenance:repair --include-expensive
    docker compose exec app php occ config:system:set maintenance_window_start --type=integer --value=1
    docker compose exec app php occ config:system:set default_phone_region --value='US' # Valid regions here https://en.wikipedia.org/wiki/ISO_3166-1
}

configure_email() {
    log_message "INFO" "Configuring Email server..."
    docker compose exec app php occ config:system:set mail_from_address --value='noreply'
    docker compose exec app php occ config:system:set mail_domain --value='DOMAIN.COM'
    docker compose exec app php occ config:system:set mail_smtpmode --value='smtp'
    docker compose exec app php occ config:system:set mail_smtpauthtype --value='LOGIN'
    docker compose exec app php occ config:system:set mail_smtpsecure --value='tls'
    docker compose exec app php occ config:system:set mail_smtpauth --value=1
    docker compose exec app php occ config:system:set mail_smtphost --value='mail.DOMAIN.COM'
    docker compose exec app php occ config:system:set mail_smtpport --value='587'
    docker compose exec app php occ config:system:set mail_smtpname --value='noreply@DOMAIN.COM'
    docker compose exec app php occ config:system:set mail_smtppassword --value='REPLACE_WITH_YOUR_EMAIL_PASSWORD'
}

configure_imaginary() {
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


install_richdocuments() {
    log_message "INFO" "Setting up RichDocuments..."
    docker compose exec app php occ app:install richdocuments
    # uncomment below to use wopi_allowlist if emty then allow all hosts
    docker compose exec app php occ config:app:set richdocuments wopi_allowlist --value "0.0.0.0/0"
    docker compose exec app php occ config:app:set richdocuments wopi_url --value https://${COLLABORA_DOMAIN}
    docker compose exec app php occ richdocuments:activate-config
    docker compose exec app php occ config:system:set skeletondirectory --value="" --type=string # emty value disables the demo/placeholder files
}


########################################################################################
########################################################################################
####################### DANGER ZONE FUNCTIONS ##########################################
########################################################################################
########################################################################################

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
    # Ensure the script is run as root
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "This script must be run as root."
        exit 1
    fi

    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirmation

    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo
        echo -e "${red_fg_strong}Starting UNINSTALL in 10 seconds. Press CTRL+C to cancel.${reset}"
        
        # Countdown timer
        for i in {10..1}; do
            echo -ne "${bold}${red_fg_strong}T-minus $i seconds...${reset}\r"
            sleep 1
        done
        # Clear the line after the countdown
        echo -ne "\033[K"

        log_message "INFO" "Proceeding with uninstallation..."
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
        options_menu
    fi
}


danger_zone_menu() {
    clear
    echo -e "\033]0;Nextcloud [DANGER ZONE]\007"
    echo -e "${red_fg_strong}${bold}╔══════════════════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_fg_strong}${bold}║ ████ WARNING: SYSTEM SELF-DESTRUCT MODE ████                                 ║${reset}"
    echo -e "${red_fg_strong}${bold}║ Proceed only if you are certain!                                             ║${reset}"
    echo -e "${red_fg_strong}${bold}║ This will DELETE ALL DATA and DESTROY NEXTCLOUD!                             ║${reset}"
    echo -e "${red_fg_strong}${bold}╚══════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo -e "${yellow_fg_strong}${bold}  [1] UNINSTALL Nextcloud${reset}"
    echo -e "  [0] BACK"
    echo -e "${red_fg_strong}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    read -p ">> ENTER COMMAND: " choice
    case $choice in
        1) uninstall_nextcloud ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            danger_zone_menu ;;
    esac
}

########################################################################################
########################################################################################
####################### BACKUP & RESTORE FUNCTIONS #####################################
########################################################################################
########################################################################################
create_backup() {
    clear
    echo -e "\033]0;Nextcloud [CREATE BACKUP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Backup & Restore / Create Backup       |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"

    log_message "INFO" "Starting backup process..."
    local backup_dir="./backups"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_file="${backup_dir}/nextcloud_backup_${timestamp}.tar.gz"

    # Ensure backup directory exists
    mkdir -p "$backup_dir"

    # Stop services to ensure consistency
    log_message "INFO" "Stopping Nextcloud services..."
    docker compose down

    # Compress volumes and database files
    log_message "INFO" "Creating compressed backup file..."
    tar -czf "$backup_file" ./nextcloud ./apps ./data ./config ./db

    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Backup completed successfully: $backup_file"
    else
        log_message "ERROR" "Failed to create backup archive!"
    fi

    # Restart services
    log_message "INFO" "Starting Nextcloud services..."
    docker compose up -d
    read -p "Press Enter to continue..."
    options_menu
}


restore_backup() {
    clear
    echo -e "\033]0;Nextcloud [RESTORE BACKUP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Backup & Restore / Restore Backup      |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"

    # Backup directory
    local backup_dir="./backups"
    
    # Prompt the user to select a backup file
    echo -e "${cyan_fg_strong}Available backups:${reset}"
    echo "-------------------------------------"
    ls "$backup_dir"/*.tar.gz 2>/dev/null
    echo "-------------------------------------"
    echo

    read -p "Enter path of the backup file to restore: " backup_file

    # Check if the user wants to cancel
    if [ "$backup_file" == "0" ]; then
        log_message "INFO" "Restore process canceled."
        read -p "Press Enter to continue..."
        options_menu
    fi

    # Validate the backup file path
    if [ ! -f "$backup_file" ]; then
        log_message "ERROR" "Backup file '$backup_file' does not exist!"
        read -p "Press Enter to continue..."
        restore_backup
    fi

    # Stop Nextcloud services
    log_message "INFO" "Stopping Nextcloud services..."
    docker compose down

    # Extract the backup file
    log_message "INFO" "Restoring files from backup..."
    tar -xzf "$backup_file" -C .

    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Files restored successfully from $backup_file."
    else
        log_message "ERROR" "Failed to extract backup archive!"
        read -p "Press Enter to continue..."
        restore_backup
    fi

    # Restart Nextcloud services
    log_message "INFO" "Starting Nextcloud services..."
    docker compose up -d

    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Nextcloud services started successfully."
        log_message "INFO" "Restore process completed."
    else
        log_message "ERROR" "Failed to start Nextcloud services. Check logs for details."
    fi

    read -p "Press Enter to continue..."
    options_menu
}


backup_restore_menu() {
    clear
    echo -e "\033]0;Nextcloud [BACKUP RESTORE]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Backup & Restore                       |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. Create Backup"
    echo "  2. Restore from Backup"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) create_backup ;;
        2) restore_backup ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            backup_restore_menu ;;
    esac
}

########################################################################################
########################################################################################
####################### APP MANAGEMENT FUNCTIONS #######################################
########################################################################################
########################################################################################

# Function to List Installed Apps
list_installed_apps() {
    clear
    echo -e "\033]0;Nextcloud [LIST INSTALLED APPS]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / List Installed Apps   |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong}Installed Apps in Nextcloud:${reset}"
    echo "-------------------------------------"
    
    # List installed apps using the Docker command with occ
    docker compose exec app php occ app:list

    echo "-------------------------------------"
    read -p "Press Enter to continue..."
    app_management_menu
}

# Function to Install a New App
install_new_app() {
    clear
    echo -e "\033]0;Nextcloud [INSTALL APP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / Install New App       |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| How to install a new app?                                   |${reset}"
    echo -e "  To find available apps, visit: ${yellow_fg_strong}https://apps.nextcloud.com/${reset}"
    echo -e "  Once you find the app, copy only the last part of the URL."
    echo -e "  For example, if the URL is: https://apps.nextcloud.com/apps/calendar"
    echo -e "  You only need to enter: ${yellow_fg_strong}calendar${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Enter app name to install: " app_name

    # Check if the user wants to cancel
    if [ "$app_name" == "0" ]; then
        app_management_menu
        return
    fi

    # Check for empty input
    if [ -z "$app_name" ]; then
        log_message "ERROR" "You must enter a valid app name!"
        read -p "Press Enter to continue..."
        install_new_app
    fi

    log_message "INFO" "Installing app '$app_name'..."
    docker compose exec app php occ app:enable "$app_name" || log_message "ERROR" "Failed to install the app. Verify the name."

    read -p "Press Enter to continue..."
    app_management_menu
}

# Function to Disable an App
disable_app() {
    clear
    echo -e "\033]0;Nextcloud [DISABLE APP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / Disable App           |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Enter app name to disable: " app_name

    # Check if the user wants to cancel
    if [ "$app_name" == "0" ]; then
        app_management_menu
        return
    fi

    # Check for empty input
    if [ -z "$app_name" ]; then
        log_message "ERROR" "You must enter a valid app name!"
        read -p "Press Enter to continue..."
        disable_app
    fi

    log_message "INFO" "Disabling app '$app_name'..."
    docker compose exec app php occ app:disable "$app_name" || log_message "ERROR" "Failed to disable the app."

    read -p "Press Enter to return to the menu..."
    app_management_menu
}

# Function to Enable an App
enable_app() {
    clear
    echo -e "\033]0;Nextcloud [ENABLE APP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / Enable App            |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Enter app name to enable: " app_name

    # Check if the user wants to cancel
    if [ "$app_name" == "0" ]; then
        app_management_menu
        return
    fi

    # Check for empty input
    if [ -z "$app_name" ]; then
        log_message "ERROR" "You must enter a valid app name!"
        read -p "Press Enter to continue..."
        enable_app
    fi

    log_message "INFO" "Enabling app '$app_name'..."
    docker compose exec app php occ app:enable "$app_name" || log_message "ERROR" "Failed to enable the app."

    read -p "Press Enter to return to the menu..."
    app_management_menu
}

# Function to Remove an App
remove_app() {
    clear
    echo -e "\033]0;Nextcloud [REMOVE APP]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / Remove App            |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Enter app name to remove: " app_name

    # Check if the user wants to cancel
    if [ "$app_name" == "0" ]; then
        app_management_menu
        return
    fi

    # Check for empty input
    if [ -z "$app_name" ]; then
        log_message "ERROR" "You must enter a valid app name!"
        read -p "Press Enter to continue..."
        remove_app
    fi

    log_message "INFO" "Removing app '$app_name'..."
    docker compose exec app php occ app:remove "$app_name" || log_message "ERROR" "Failed to remove the app."

    read -p "Press Enter to return to the menu..."
    app_management_menu
}


app_management_menu() {
    clear
    echo -e "\033]0;Nextcloud [APP MANAGEMENT]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management                         |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. List Installed Apps"
    echo "  2. Install a New App"
    echo "  3. Disable an App"
    echo "  4. Enable an App"
    echo "  5. Remove an App"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) list_installed_apps ;;
        2) install_new_app ;;
        3) disable_app ;;
        4) enable_app ;;
        5) remove_app ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            app_management_menu ;;
    esac
}

########################################################################################
########################################################################################
####################### USER MANAGEMENT FUNCTIONS ######################################
########################################################################################
########################################################################################
# Function to list users
list_users() {
    clear
    echo -e "\033]0;Nextcloud [LIST USERS]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / List Users           |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo
    echo -e "${cyan_fg_strong}Users report${reset}"
    echo "-------------------------------------"
    docker compose exec app php occ user:report
    echo "-------------------------------------"
    read -p "Press Enter to continue..."
    user_management_menu
}

reset_user_password() {
    clear
    echo -e "\033]0;Nextcloud [RESET USER PASSWORD]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / Reset User Password  |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo

    # Export usernames to a file
    user_list_file="user_list.txt"
    log_message "INFO" "Fetching user list..."
    docker compose exec -T app php occ user:list | awk -F ':' '{print $1}' | sed 's/  - //g' > "$user_list_file"

    if [ ! -s "$user_list_file" ]; then
        log_message "ERROR" "Failed to retrieve user list!"
        read -p "Press Enter to return to the menu..."
        user_management_menu
        return
    fi

    echo -e "${cyan_fg_strong}Available usernames:${reset}"
    echo "-------------------------------------"
    cat "$user_list_file"
    echo "-------------------------------------"
    echo

    read -p "Enter username for password reset: " username

    # Check if the user wants to cancel
    if [ "$username" == "0" ]; then
        rm -rf "$user_list_file"
        user_management_menu
        return
    fi

    # Validate if the username exists in the file
    if ! grep -qw "$username" "$user_list_file"; then
        log_message "ERROR" "User '$username' does not exist!"
        read -p "Press Enter to continue..."
        reset_user_password
        return
    fi

    # Ask if the user wants to generate a random password
    echo
    read -p "Generate a random password? [Y/N]: " generate_random
    if [[ "$generate_random" =~ ^[Yy]$ ]]; then
        # Generate a secure random password (12 characters by default)
        password=$(openssl rand -base64 12)
        log_message "INFO" "Generated random password."
    else
        # Prompt for password input
        read -sp "Enter new password for $username: " password
        echo
    fi

    # Validate the password input
    if [ -z "$password" ]; then
        log_message "ERROR" "Password cannot be empty!"
        read -p "Press Enter to continue..."
        reset_user_password
        return
    fi

    # Run the command with OC_PASS passed directly
    log_message "INFO" "Resetting password..."
    docker compose exec -T -e OC_PASS="$password" app php occ user:resetpassword --password-from-env "$username"

    # Check the success of the command
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Password reset successfully. $username can now login with password: ${yellow_fg_strong}$password${reset}"
    else
        log_message "ERROR" "Failed to reset password for $username."
        read -p "Press Enter to try again..."
        reset_user_password
        return
    fi

    read -p "Press Enter to continue..."
    rm -rf "$user_list_file"
    user_management_menu
}

# Function to add a new user
add_new_user() {
    clear
    echo -e "\033]0;Nextcloud [ADD NEW USER]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / Add New User         |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo

    # Export usernames to a file
    user_list_file="user_list.txt"
    log_message "INFO" "Fetching user list..."
    docker compose exec -T app php occ user:list | awk -F ':' '{print $1}' | sed 's/  - //g' > "$user_list_file"

    if [ ! -s "$user_list_file" ]; then
        log_message "ERROR" "Failed to retrieve user list!"
        read -p "Press Enter to return to the menu..."
        user_management_menu
        return
    fi
    
    echo
    read -p "Enter username for new user: " username

    # Check if the user wants to cancel
    if [ "$username" == "0" ]; then
        rm -rf "$user_list_file"
        user_management_menu
        return
    fi

    # Validate if the username already exists
    if grep -qw "$username" "$user_list_file"; then
        log_message "ERROR" "User '$username' already exists!"
        read -p "Press Enter to continue..."
        add_new_user
        return
    fi

    # Ask if the user wants to generate a random password
    echo
    read -p "Generate a random password? [Y/N]: " generate_random
    if [[ "$generate_random" =~ ^[Yy]$ ]]; then
        # Generate a secure random password (12 characters by default)
        password=$(openssl rand -base64 12)
        log_message "INFO" "Generated random password."
    else
        # Prompt for password input
        read -sp "Enter new password for $username: " password
        echo
    fi

    # Validate the password input
    if [ -z "$password" ]; then
        log_message "ERROR" "Password cannot be empty!"
        read -p "Press Enter to continue..."
        add_new_user
        return
    fi

    # Add the new user
    log_message "INFO" "Adding new user: $username..."
    docker compose exec -T -e OC_PASS="$password" app php occ user:add --password-from-env --display-name="$username" "$username"

    # Check the success of the command
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "User $username added successfully."
        log_message "INFO" "$username can now login with password: ${yellow_fg_strong}$password${reset}" 
    else
        log_message "ERROR" "Failed to add user $username."
        read -p "Press Enter to try again..."
        add_new_user
        return
    fi

    # Cleanup
    rm -rf "$user_list_file"
    read -p "Press Enter to continue..."
    user_management_menu
}

# Function to activate a user
activate_user() {
    clear
    echo -e "\033]0;Nextcloud [ACTIVATE USER]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / Activate User        |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo

    # Export usernames to a file
    user_list_file="user_list.txt"
    log_message "INFO" "Fetching user list..."
    docker compose exec -T app php occ user:list | awk -F ':' '{print $1}' | sed 's/  - //g' > "$user_list_file"

    if [ ! -s "$user_list_file" ]; then
        log_message "ERROR" "Failed to retrieve user list!"
        read -p "Press Enter to return to the menu..."
        user_management_menu
        return
    fi

    echo -e "${cyan_fg_strong}Available usernames:${reset}"
    echo "-------------------------------------"
    cat "$user_list_file"
    echo "-------------------------------------"
    echo

    read -p "Enter username to activate: " username

    # Check if the user wants to cancel
    if [ "$username" == "0" ]; then
        rm -rf "$user_list_file"
        user_management_menu
        return
    fi

    # Validate if the username exists in the file
    if ! grep -qw "$username" "$user_list_file"; then
        log_message "ERROR" "User '$username' does not exist!"
        read -p "Press Enter to continue..."
        activate_user
        return
    fi

    log_message "INFO" "Activating $username..."
    docker compose exec app php occ user:enable "$username"


    if [[ $? -eq 0 ]]; then
        log_message "INFO" "User $username activated successfully."
    else
        log_message "ERROR" "Failed to activate user $username."
    fi
    read -p "Press Enter to continue..."
    user_management_menu
}

# Function to deactivate a user
deactivate_user() {
    clear
    echo -e "\033]0;Nextcloud [DEACTIVATE USER]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / Deactivate User      |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo

    # Export usernames to a file
    user_list_file="user_list.txt"
    log_message "INFO" "Fetching user list..."
    docker compose exec -T app php occ user:list | awk -F ':' '{print $1}' | sed 's/  - //g' > "$user_list_file"

    if [ ! -s "$user_list_file" ]; then
        log_message "ERROR" "Failed to retrieve user list!"
        read -p "Press Enter to return to the menu..."
        user_management_menu
        return
    fi

    echo -e "${cyan_fg_strong}Available usernames:${reset}"
    echo "-------------------------------------"
    cat "$user_list_file"
    echo "-------------------------------------"
    echo

    read -p "Enter username to deactivate: " username

    # Check if the user wants to cancel
    if [ "$username" == "0" ]; then
        rm -rf "$user_list_file"
        user_management_menu
        return
    fi

    # Validate if the username exists in the file
    if ! grep -qw "$username" "$user_list_file"; then
        log_message "ERROR" "User '$username' does not exist!"
        read -p "Press Enter to continue..."
        deactivate_user
        return
    fi

    log_message "INFO" "Deactivating $username..."
    docker compose exec app php occ user:disable "$username"


    if [[ $? -eq 0 ]]; then
        log_message "INFO" "User $username deactivated successfully."
    else
        log_message "ERROR" "Failed to deactivate user $username."
    fi
    read -p "Press Enter to continue..."
    user_management_menu
}

# Function to delete a user
delete_user() {
    clear
    echo -e "\033]0;Nextcloud [DELETE USER]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management / Delete User          |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo

    # Export usernames to a file
    user_list_file="user_list.txt"
    log_message "INFO" "Fetching user list..."
    docker compose exec -T app php occ user:list | awk -F ':' '{print $1}' | sed 's/  - //g' > "$user_list_file"

    if [ ! -s "$user_list_file" ]; then
        log_message "ERROR" "Failed to retrieve user list!"
        read -p "Press Enter to return to the menu..."
        user_management_menu
        return
    fi

    echo -e "${cyan_fg_strong}Available usernames:${reset}"
    echo "-------------------------------------"
    cat "$user_list_file"
    echo "-------------------------------------"
    echo

    read -p "Enter username to delete: " username

    # Check if the user wants to cancel
    if [ "$username" == "0" ]; then
        rm -rf "$user_list_file"
        user_management_menu
        return
    fi

    # Validate if the username exists in the file
    if ! grep -qw "$username" "$user_list_file"; then
        log_message "ERROR" "User '$username' does not exist!"
        read -p "Press Enter to continue..."
        delete_user
        return
    fi

    # Warning and confirmation prompt
    echo
    echo -e "${red_fg_strong}${bold}╔═══════════════ DANGER ZONE ═════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_fg_strong}${bold}║ WARNING: You are about to PERMANENTLY DELETE the user                               ║${reset}"
    echo -e "${red_fg_strong}${bold}║ This action will ERASE ALL DATA associated with this user, including files,         ║${reset}"
    echo -e "${red_fg_strong}${bold}║ settings, and activity history.                                                     ║${reset}"
    echo -e "${red_fg_strong}${bold}║                                                                                     ║${reset}"
    echo -e "${red_fg_strong}${bold}║ Ensure you have created backups of any critical information BEFORE proceeding.      ║${reset}"
    echo -e "${red_fg_strong}${bold}╚═════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo
    echo -n -e "${yellow_fg_strong}Are you sure you want to delete $username? [Y/N]: ${reset}"
    read -r confirm

    case "$confirm" in
        [Yy]*)
            log_message "INFO" "Deleting $username..."
            docker compose exec app php occ user:delete "$username"

            if [[ $? -eq 0 ]]; then
                log_message "INFO" "User $username deleted successfully."
            else
                log_message "ERROR" "Failed to delete user $username."
            fi
            ;;
        [Nn]*)
            log_message "INFO" "Operation canceled. No changes were made."
            read -p "Press Enter to continue..."
            user_management_menu
            ;;
        *)
            log_message "ERROR" "Invalid input. Please enter Y or N."
            read -p "Press Enter to try again..."
            delete_user
            ;;
    esac

    # Cleanup
    rm -rf "$user_list_file"
    read -p "Press Enter to continue..."
    user_management_menu
}

user_management_menu() {
    clear
    echo -e "\033]0;Nextcloud [USER MANAGEMENT]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / User Management                        |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. List Users"
    echo "  2. Reset User Password"
    echo "  3. Add New User"
    echo "  4. Activate User"
    echo "  5. Deactivate User"
    echo "  6. Delete User"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) list_users ;;
        2) reset_user_password ;;
        3) add_new_user ;;
        4) activate_user ;;
        5) deactivate_user ;;
        6) delete_user ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            user_management_menu ;;
    esac
}

########################################################################################
########################################################################################
####################### MAINTENANCE FUNCTIONS ##########################################
########################################################################################
########################################################################################
toggle_maintenance_mode() {
    clear
    echo -e "\033]0;Nextcloud [TOGGLE MAINTENANCE MODE]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Toggle Maintenance Mode  |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"

    current_status=$(docker compose exec -T app php occ maintenance:mode | grep -oE '(enabled|disabled)')
    if [[ $current_status == "enabled" ]]; then
        docker compose exec -T app php occ maintenance:mode --off
        log_message "INFO" "Maintenance mode disabled."
    else
        docker compose exec -T app php occ maintenance:mode --on
        log_message "INFO" "Maintenance mode enabled."
    fi
    read -p "Press Enter to continue..."
    maintenance_menu
}

clear_file_cache() {
    clear
    echo -e "\033]0;Nextcloud [CLEAR FILE CACHE]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Clear File Cache         |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"

    # Cleanup file cache
    log_message "INFO" "Clearing file cache..."
    docker compose exec -T app php occ files:cleanup

    # Cleanup avatar cache
    log_message "INFO" "Clearing avatar cache..."
    docker compose exec -T app php occ user:clear-avatar-cache

    # Cleanup remote storages
    log_message "INFO" "Cleaning up remote storages with no matching entries..."
    docker compose exec -T app php occ sharing:cleanup-remote-storages

    # Delete orphan shares
    log_message "INFO" "Deleting orphan shares..."
    docker compose exec -T app php occ sharing:delete-orphan-shares

    log_message "INFO" "Cache cleared successfully."
    read -p "Press Enter to continue..."
    maintenance_menu
}


clear_trashbin() {
    clear
    echo -e "\033]0;Nextcloud [CLEAR TRASHBIN]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Clear Trashbin           |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    log_message "INFO" "clearing trashbin for all users..."

    docker compose exec app php occ trashbin:cleanup --all-users
    log_message "INFO" "Trashbin cleared successfully."

    read -p "Press Enter to continue..."
    maintenance_menu
}


optimize_database() {
    clear
    echo -e "\033]0;Nextcloud [OPTIMIZE DATABASE]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Optimize Database        |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    log_message "INFO" "Starting database optimization..."

    # Add missing columns
    log_message "INFO" "Checking and adding missing optional columns to the database tables..."
    docker compose exec -T app php occ db:add-missing-columns
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Missing columns added successfully."
    else
        log_message "ERROR" "Failed to add missing columns."
    fi

    # Add missing indices
    log_message "INFO" "Checking and adding missing indices to the database tables..."
    docker compose exec -T app php occ db:add-missing-indices
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Missing indices added successfully."
    else
        log_message "ERROR" "Failed to add missing indices."
    fi

    # Add missing primary keys
    log_message "INFO" "Checking and adding missing primary keys to the database tables..."
    docker compose exec -T app php occ db:add-missing-primary-keys
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Missing primary keys added successfully."
    else
        log_message "ERROR" "Failed to add missing primary keys."
    fi

    # Convert filecache ID columns to BigInt
    log_message "INFO" "Converting filecache ID columns to BigInt for large datasets..."
    docker compose exec -T app php occ db:convert-filecache-bigint
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Filecache ID columns converted to BigInt successfully."
    else
        log_message "ERROR" "Failed to convert filecache ID columns to BigInt."
    fi

    log_message "INFO" "Database optimization complete."
    read -p "Press Enter to continue..."
    maintenance_menu
}

check_system_status() {
    clear
    echo -e "\033]0;Nextcloud [SYSTEM STATUS CHECK]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Check System Status      |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    log_message "INFO" "Checking system status..."

    # Check system status
    log_message "INFO" "Fetching general system status..."
    docker compose exec -T app php occ status

    # Validate security and setup warnings
    log_message "INFO" "Validating security and setup warnings..."
    docker compose exec -T app php occ check

    # Check disk space usage
    log_message "INFO" "Checking disk space usage..."
    docker compose exec -T app du -sh /var/www/html/data
    docker compose exec -T app du -sh /var/www/html/custom_apps
    docker compose exec -T app du -sh /var/www/html/config

    # Check notify push
    log_message "INFO" "Checking notify_push..."
    docker compose exec app php occ notify_push:metrics
    if ! docker compose exec app php occ notify_push:self-test; then
        log_message "ERROR" "Failed to perform notify_push:self-test."
    fi

    # List enabled apps
    log_message "INFO" "Checking for server and app updates..."
    docker compose exec -T app php occ update:check

    # Display completion message
    log_message "INFO" "System status check complete."
    read -p "Press Enter to continue..."
    maintenance_menu
}

update_nextcloud() {
    clear
    echo -e "\033]0;Nextcloud [UPDATE NEXTCLOUD]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance / Update Nextcloud         |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    log_message "INFO" "Starting Nextcloud update process..."

    # Step 1: Bring down the current Nextcloud stack
    log_message "INFO" "Stopping Nextcloud services..."
    if ! docker compose down; then
        log_message "ERROR" "Failed to stop Nextcloud services. Aborting update process."
        read -p "Press Enter to return to the menu..."
        maintenance_menu
        return
    fi

    # Step 2: Pull the latest images
    log_message "INFO" "Pulling latest Docker images for Nextcloud and its services..."
    if ! docker compose pull; then
        log_message "ERROR" "Failed to pull latest Docker images. Aborting update process."
        read -p "Press Enter to return to the menu..."
        maintenance_menu
        return
    fi

    # Step 3: Start the updated Nextcloud stack
    log_message "INFO" "Starting Nextcloud services with updated images..."
    if ! docker compose up -d; then
        log_message "ERROR" "Failed to start Nextcloud services. Please check your Docker setup."
        read -p "Press Enter to return to the menu..."
        maintenance_menu
        return
    fi

    # Step 4: Run Nextcloud database and application updates
    log_message "INFO" "Running Nextcloud database and application updates..."
    if ! docker compose exec -T app php occ upgrade; then
        log_message "ERROR" "Nextcloud upgrade command failed. Services are running but updates may not be applied."
        read -p "Press Enter to return to the menu..."
        maintenance_menu
        return
    fi

    # Completion message
    log_message "INFO" "Nextcloud updated successfully."
    read -p "Press Enter to continue..."
    maintenance_menu
}


maintenance_menu() {
    clear
    echo -e "\033]0;Nextcloud [MAINTENANCE]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Maintenance                            |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. Toggle Maintenance Mode"
    echo "  2. Clear File Cache"
    echo "  3. Clear trashbin for all users"
    echo "  4. Optimize Database"
    echo "  5. Check System Status"
    echo "  6. Update Nextcloud"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) toggle_maintenance_mode ;;
        2) clear_file_cache ;;
        3) clear_trashbin ;;
        4) optimize_database ;;
        5) check_system_status ;;
        6) update_nextcloud ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            maintenance_menu ;;
    esac
}



########################################################################################
####################### OPTIONS MENU  ##################################################
########################################################################################
options_menu() {
    clear
    echo -e "\033]0;Nextcloud [OPTIONS]\007"
    echo -e "${blue_fg_strong}| > / Home / Options                                          |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. Maintenance"
    echo "  2. User Management"
    echo "  3. App Management"
    echo "  4. Backup & Restore"
    echo "  5. DANGER ZONE"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) maintenance_menu ;;
        2) user_management_menu ;;
        3) app_management_menu ;;
        4) backup_restore_menu ;;
        5) danger_zone_menu ;;
        0) home ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            options_menu ;;
    esac
}

########################################################################################
####################### HOME MENU  #####################################################
########################################################################################
home() {
    clear
    echo -e "\033]0;Nextcloud [HOME]\007"
    echo -e "${blue_fg_strong}| > / Home                                                    |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. Install Nextcloud"
    echo "  2. Rescan Data folder for new files"
    echo "  3. Options"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Exit"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice

    # Default to choice 1 if no input
    choice=${choice:-1}
    case $choice in
        1) install_nextcloud ;;
        2) rescan_files ;;
        3) options_menu ;;
        0) exit_program ;;
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