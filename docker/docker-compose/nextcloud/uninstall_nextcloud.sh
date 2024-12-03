#!/bin/bash

# Config variables
SERVICE_ACCOUNT="svc_nextcloud_docker"

# ANSI Escape Code for Colors
reset="\033[0m"
red_fg_strong="\033[91m"
green_fg_strong="\033[92m"
yellow_bg="\033[43m"
red_bg="\033[41m"



# Function to log messages with timestamps and colors
log_message() {
    current_time=$(date +'%H:%M:%S') # Current time
    case "$1" in
        "INFO")
            echo -e "${green_fg_strong}[$current_time] INFO: $2${reset}"
            ;;
        "WARN")
            echo -e "${yellow_bg}[$current_time] WARN: $2${reset}"
            ;;
        "ERROR")
            echo -e "${red_fg_strong}[$current_time] ERROR: $2${reset}"
            ;;
        *)
            echo -e "${green_fg_strong}[$current_time] DEBUG: $2${reset}"
            ;;
    esac
}

# Function to display Danger Zone warning
display_danger_zone_warning() {
    echo
    echo -e "${red_bg}╔════ DANGER ZONE ═══════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_bg}║ WARNING: This will delete all data related to Nextcloud and its configuration.     ║${reset}"
    echo -e "${red_bg}║ If you want to keep any data, make sure to create a backup before proceeding.      ║${reset}"
    echo -e "${red_bg}╚════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo
}

# Function to uninstall Nextcloud
uninstall_nextcloud() {
    display_danger_zone_warning
    echo -n "Are you sure you want to proceed? [Y/N]: "
    read confirmation

    if [ "$confirmation" = "Y" ] || [ "$confirmation" = "y" ]; then
        log_message "INFO" "Proceeding with uninstallation..."

        # Ensure the script is run as root
        if [[ $EUID -ne 0 ]]; then
            log_message "ERROR" "This script must be run as root."
            exit 1
        fi

        # Remove Docker Containers, Volumes, and Network for Nextcloud
        log_message "INFO" "Removing nextcloud containers and volumes"
        docker compose down --volumes --remove-orphans

        # Remove Nextcloud Data
        log_message "INFO" "Deleting Nextcloud data..."
        rm -rf nextcloud apps data db

        # Remove configuration files and other related directories
        log_message "INFO" "Removing configuration files..."
        rm -rf config .env cron.sh redis-session.ini remoteip.conf

        # Remove Service Account
        log_message "INFO" "Removing Service Account $SERVICE_ACCOUNT"
        sudo userdel -r $SERVICE_ACCOUNT

        # Final message
        log_message "INFO" "Uninstallation completed. Nextcloud has been fully removed."
    else
        log_message "INFO" "Uninstallation canceled. No changes were made."
    fi
}

# Ensure the script is executed as root
if [[ $EUID -ne 0 ]]; then
    log_message "ERROR" "This script must be run as root."
    exit 1
fi

# Call the uninstall function
uninstall_nextcloud

exit 0
