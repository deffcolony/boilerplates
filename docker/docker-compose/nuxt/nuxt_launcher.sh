#!/bin/bash
set -euo pipefail

# Config variables
REPO_URL="https://gitlab.DOMAIN.COM/mynuxtproject.git"
PROJECT_DIR=$(basename -s .git "$REPO_URL")
IMAGE_NAME="$PROJECT_DIR:latest"


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
####################### DANGER ZONE FUNCTIONS ##########################################
########################################################################################
########################################################################################

# Function to display Danger Zone warning
display_danger_zone_warning() {
    echo
    echo -e "${red_bg}${bold}╔════ DANGER ZONE ═══════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_bg}${bold}║ WARNING: This action will PERMANENTLY DELETE all data related to Nuxt!             ║${reset}"
    echo -e "${red_bg}${bold}║ Ensure you have created backups if you want to retain any information.             ║${reset}"
    echo -e "${red_bg}${bold}║ This includes files, databases, configurations, and Docker containers.             ║${reset}"
    echo -e "${red_bg}${bold}╚════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo
}

# Function to uninstall Nuxt
uninstall_nuxt() {
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
        # Remove Docker Containers, Volumes, and Network for Nuxt
        log_message "INFO" "Stopping and removing Nuxt containers, volumes, and network..."
        docker compose down --volumes --remove-orphans || log_message "WARN" "Docker compose down encountered issues. Continuing cleanup."

        # Remove Nuxt Data
        log_message "INFO" "Deleting $PROJECT_DIR data..."
        rm -rf $PROJECT_DIR || log_message "WARN" "Failed to remove some data directories."

        # Remove configuration files and other related directories
        log_message "INFO" "Removing configuration files..."
        rm -rf config .env cron.sh redis-session.ini remoteip.conf || log_message "WARN" "Failed to remove some configuration files."

        # Final message
        log_message "INFO" "Nuxt uninstalled successfully."
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
    echo -e "\033]0;Nuxt [DANGER ZONE]\007"
    echo -e "${red_fg_strong}${bold}╔══════════════════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_fg_strong}${bold}║ ████ WARNING: SYSTEM SELF-DESTRUCT MODE ████                                 ║${reset}"
    echo -e "${red_fg_strong}${bold}║ Proceed only if you are certain!                                             ║${reset}"
    echo -e "${red_fg_strong}${bold}║ This will DELETE ALL DATA and DESTROY NUXT!                                  ║${reset}"
    echo -e "${red_fg_strong}${bold}╚══════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo -e "${yellow_fg_strong}${bold}  [1] UNINSTALL Nuxt${reset}"
    echo -e "  [0] BACK"
    echo -e "${red_fg_strong}${bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    read -p ">> ENTER COMMAND: " choice
    case $choice in
        1) uninstall_nuxt ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            danger_zone_menu ;;
    esac
}

########################################################################################
########################################################################################
####################### PLUGIN MANAGEMENT FUNCTIONS ####################################
########################################################################################
########################################################################################

# Function to List Installed Plugins
list_installed_plugins() {
    clear
    echo -e "\033]0;Nextcloud [LIST INSTALLED PLUGINS]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / App Management / List Installed Plugins   |${reset}"
    echo -e "${blue_fg_strong}=================================================================${reset}"
    echo -e "${cyan_fg_strong}Installed Plugins in $PROJECT_DIR: ${reset}"
    echo "-------------------------------------"
    
    # List installed nuxt plugins
    ls "$PROJECT_DIR/plugins/"

    echo "-------------------------------------"
    read -p "Press Enter to continue..."
    plugin_management_menu
}


# Function to check if npx, Nuxt, npm, and the appropriate package manager are installed
check_npx_nuxt_installed() {
    clear
    log_message "INFO" "Checking if npx, Nuxt, npm, and the appropriate package manager are installed..."

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        log_message "ERROR" "npm is not installed."

        # Determine which package manager to use
        case "$(command -v apt yum dnf pacman | head -n 1)" in
            *apt*)
                log_message "INFO" "Using APT as package manager."
                read -p "Would you like to install Node.js? [Y/N]: " install_choice
                if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                    log_message "INFO" "Installing Node.js via APT..."
                    sudo apt update && sudo apt install -y nodejs npm
                else
                    log_message "ERROR" "Please install Node.js manually from https://nodejs.org/."
                fi
                ;;
            *yum*)
                log_message "INFO" "Using YUM as package manager."
                read -p "Would you like to install Node.js? [Y/N]: " install_choice
                if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                    log_message "INFO" "Installing Node.js via YUM..."
                    sudo yum install -y nodejs npm
                else
                    log_message "ERROR" "Please install Node.js manually from https://nodejs.org/."
                fi
                ;;
            *dnf*)
                log_message "INFO" "Using DNF as package manager."
                read -p "Would you like to install Node.js? [Y/N]: " install_choice
                if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                    log_message "INFO" "Installing Node.js via DNF..."
                    sudo dnf install -y nodejs npm
                else
                    log_message "ERROR" "Please install Node.js manually from https://nodejs.org/."
                fi
                ;;
            *pacman*)
                log_message "INFO" "Using Pacman as package manager."
                read -p "Would you like to install Node.js? [Y/N]: " install_choice
                if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                    log_message "INFO" "Installing Node.js via Pacman..."
                    sudo pacman -S nodejs npm --noconfirm
                else
                    log_message "ERROR" "Please install Node.js manually from https://nodejs.org/."
                fi
                ;;
            *)
                log_message "ERROR" "No supported package manager detected. Please install Node.js manually from https://nodejs.org/."
                ;;
        esac

        # Check if npm was successfully installed after attempts
        if ! command -v npm &> /dev/null; then
            log_message "ERROR" "Node.js installation failed or was not installed. Cannot proceed."
            read -p "Press Enter to continue..."
            options_menu
            return
        else
            log_message "INFO" "Node.js and npm have been installed."
            read -p "Press Enter to continue..."
            options_menu
        fi
    fi


    # Check if Nuxt is installed by checking for 'npx nuxi' command
    if ! npx nuxi --version &> /dev/null; then
        log_message "ERROR" "Nuxt is not installed. Would you like to install Nuxt? [Y/N]"
        read -p "Your choice: " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            log_message "INFO" "Installing Nuxt..."
            npm install nuxt@latest  # Install Nuxt globally or as a project dependency
            log_message "INFO" "Nuxt has been installed."
        else
            log_message "INFO" "Please install Nuxt manually to continue."
            read -p "Press Enter to continue..."
            install_new_plugin
            return
        fi
    fi
}

install_nuxt_tailwindcss() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt TailwindCSS..."
    npx nuxi@latest module add tailwindcss
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_i18n() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt i18n..."
    npx nuxi@latest module add @nuxtjs/i18n
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_icon() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt Icon..."
    npx nuxi module add icon
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_robots() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt Robots..."
    npx nuxi module add robots
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_sitemap() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt Sitemap..."
    npx nuxi module add @nuxtjs/sitemap
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_ogimage() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt OG Image..."
    npx nuxi module add og-image
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_schemaorg() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt Schema.org..."
    npx nuxi module add schema-org
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_linkchecker() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt Link Checker..."
    npx nuxi module add link-checker
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_seoutils() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt SEO Utils..."
    npx nuxi module add nuxt-seo-utils
    read -p "Press Enter to continue..."
    install_new_plugin
}

install_nuxt_siteconfig() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt SiteConfig..."
    npx nuxi module add site-config
    read -p "Press Enter to continue..."
    install_new_plugin
}



# Function to Install a New Plugin
install_new_plugin() {
    clear
    echo -e "\033]0;Nuxt [INSTALL PLUGIN]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Plugin Management / Install New Plugin    |${reset}"
    echo -e "${blue_fg_strong}=================================================================${reset}"
    
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Nuxt tailwindcss                                            |${reset}"
    echo "  1. Install Tailwind CSS"
    echo -e "  More info: ${yellow_fg_strong}https://tailwindcss.nuxtjs.org/getting-started/installation${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Nuxt i18n                                                   |${reset}"
    echo "  2. Install Nuxt i18n"
    echo -e "  More info: ${yellow_fg_strong}https://i18n.nuxtjs.org/docs/getting-started${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Nuxt Icon                                                   |${reset}"
    echo "  3. Install Nuxt Icon"
    echo -e "  More info: ${yellow_fg_strong}https://nuxt.com/modules/icon${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Nuxt SEO                                                    |${reset}"
    echo "  4. Install Nuxt Robots"
    echo "  5. Install Nuxt Sitemap"
    echo "  6. Install Nuxt OG Image"
    echo "  7. Install Nuxt Schema.org" 
    echo "  8. Install Nuxt Link Checker"
    echo "  9. Install Nuxt SEO Utils"
    echo "  10. Install Nuxt Site Config"
    echo -e "  More info: ${yellow_fg_strong}https://nuxtseo.com/docs/nuxt-seo/getting-started/introduction${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) install_nuxt_tailwindcss ;;
        2) install_nuxt_i18n ;;
        3) install_nuxt_icon ;;
        4) install_nuxt_robots ;;
        5) install_nuxt_sitemap ;;
        6) install_nuxt_ogimage ;;
        7) install_nuxt_schemaorg ;;
        8) install_nuxt_linkchecker ;;
        9) install_nuxt_seoutils ;;
        10) install_nuxt_siteconfig ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            options_menu ;;
    esac
}





plugin_management_menu() {
    clear
    echo -e "\033]0;Nextcloud [PLUGIN MANAGEMENT]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Plugin Management                      |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. List installed plugins"
    echo "  2. Install new plugin"
    echo "  3. Remove a plugin"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) list_installed_plugins ;;
        2) install_new_plugin ;;
        3) remove_plugin ;;
        0) options_menu ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            plugin_management_menu ;;
    esac
}

########################################################################################
####################### OPTIONS MENU  ##################################################
########################################################################################
# Function to allow the user to change the repository URL
change_repo_url() {
    clear
    echo -e "\033]0;Nuxt [CHANGE REPO URL]\007"
    echo -e "${blue_fg_strong}| > / Home / Options / Change repository URL                  |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Cancel"
    echo
    
    read -p "Enter new repository URL: " new_repo_url

    # Allow user to return to options_menu
    if [[ "$new_repo_url" == "0" ]]; then
        options_menu
        return
    fi

    # Check if input is empty
    if [[ -z "$new_repo_url" ]]; then
        log_message "ERROR" "Repository URL cannot be empty!"
        read -p "Press Enter to continue..."
        change_repo_url
        return
    fi

    # Validate URL format (must start with http:// or https://)
    if [[ ! "$new_repo_url" =~ ^https?:// ]]; then
        log_message "ERROR" "Invalid URL! The repository URL must start with 'http://' or 'https://'."
        read -p "Press Enter to continue..."
        change_repo_url
        return
    fi

    # Update variables
    REPO_URL="$new_repo_url"
    PROJECT_DIR=$(basename -s .git "$REPO_URL") # Automatically update project directory
    IMAGE_NAME="$PROJECT_DIR:latest"

    log_message "INFO" "Repository URL updated to: $REPO_URL"
    log_message "INFO" "Project directory set to: $PROJECT_DIR"
    read -p "Press Enter to continue..."
    options_menu
}


# Function to install Nuxt
install_nuxt() {
    check_npx_nuxt_installed
    clear
    log_message "INFO" "Installing Nuxt..."

    # Install Nuxt using npx
    npx nuxi@latest init
    read -p "Press Enter to continue..."
    options_menu
}


options_menu() {
    clear
    echo -e "\033]0;Nuxt [OPTIONS]\007"
    echo -e "${blue_fg_strong}| > / Home / Options                                          |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| What would you like to do?                                  |${reset}"
    echo "  1. Change repository URL"
    echo "  2. Plugin Management"
    echo "  3. Backup & Restore"
    echo "  4. Install Nuxt.js"
    echo "  5. DANGER ZONE"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  0. Back"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice
    case $choice in
        1) change_repo_url ;;
        2) plugin_management_menu ;;
        3) backup_restore_menu ;;
        4) install_nuxt ;;
        5) danger_zone_menu ;;
        0) home ;;
        *) 
            log_message "ERROR" "Invalid number. Please insert a valid number."
            read -p "Press Enter to continue..."
            options_menu ;;
    esac
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

# Shared function to pull the latest code
pull_latest_code() {
    if [ -d "$PROJECT_DIR" ]; then
        log_message "INFO" "Directory $PROJECT_DIR exists, pulling latest changes..."
        cd "$PROJECT_DIR" || { log_message "ERROR" "Failed to change directory to $PROJECT_DIR"; exit 1; }
        git pull "$REPO_URL"
    else
        log_message "INFO" "Directory $PROJECT_DIR does not exist, cloning repository..."
        git clone "$REPO_URL" "$PROJECT_DIR"
        cd "$PROJECT_DIR" || { log_message "ERROR" "Failed to change directory to $PROJECT_DIR"; exit 1; }
    fi
}

# Shared function to build and deploy
build_and_deploy() {
    local profile=$1
    log_message "INFO" "Building Docker image for $profile..."
    docker compose --profile "$profile" down
    docker compose --profile "$profile" up -d --build
    log_message "INFO" "Nuxt Docker image for $profile built successfully."
    read -p "Press Enter to continue..."
    home
}

# Shared function to build only
build_only() {
    local profile=$1
    local dockerfile="dockerfile.$profile"
    local image_name="nuxt-app-$profile"

    log_message "INFO" "Building Docker image for $profile..."
    docker build -t "$image_name" -f "$dockerfile" .
    if [ $? -eq 0 ]; then
        log_message "INFO" "Nuxt Docker image for $profile built successfully."
    else
        log_message "ERROR" "Failed to build Docker image for $profile."
    fi
    read -p "Press Enter to continue..."
    home
}

# Dev build and deploy
build_deploy_dev() {
    pull_latest_code
    build_and_deploy "dev"
}

# Prod build and deploy
build_deploy_prod() {
    pull_latest_code
    build_and_deploy "prod"
}

# Dev build only
build_dev() {
    pull_latest_code
    build_only "dev"
}

# Prod build only
build_prod() {
    pull_latest_code
    build_only "prod"
}



########################################################################################
####################### HOME MENU  #####################################################
########################################################################################
home() {
    clear
    echo -e "\033]0;Nuxt [HOME]\007"
    echo -e "${blue_fg_strong}| > / Home                                                    |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Development                                                 |${reset}"
    echo "  1. [DEV] Build & Deploy"
    echo "  2. [DEV] Build only"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Production                                                  |${reset}"
    echo "  3. [PROD] Build & Deploy"
    echo "  4. [PROD] Build only"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}| Menu Options:                                               |${reset}"
    echo "  5. Options"
    echo "  0. Exit"
    echo -e "${cyan_fg_strong} _____________________________________________________________${reset}"
    echo -e "${cyan_fg_strong}|                                                             |${reset}"
    read -p "  Choose Your Destiny: " choice

    # Default to choice 1 if no input
    choice=${choice:-1}
    case $choice in
        1) build_deploy_dev ;;
        2) build_dev ;;
        3) build_deploy_prod ;;
        4) build_prod ;;
        5) options_menu ;;
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