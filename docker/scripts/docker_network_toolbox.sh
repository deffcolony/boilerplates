#!/bin/bash

echo -e "\033]0;Docker Network Toolbox\007"

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

backup_folder="docker_network_backups"

# Function to log messages with timestamps and colors
log_message() {
    # This is only time
    current_time=$(date +'%H:%M:%S')
    # This is with date and time
    # current_time=$(date +'%Y-%m-%d %H:%M:%S')
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

# Check if jq is installed, and if not, install it
if ! command -v jq &> /dev/null; then
    log_message "INFO" "Installing jq..."
    # Installation commands based on the system's package manager
    if command -v apt &> /dev/null; then
        sudo apt install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        log_message "ERROR" "jq is not installed, and no known package manager found. Please install jq manually."
        exit 1
    fi
    log_message "INFO" "jq installed successfully."
fi

# Function to backup Docker networks
backup_networks() {
    log_message "INFO" "Backing up Docker networks..."
    mkdir -p "$backup_folder"

    # Iterate through Docker networks
    docker network ls --format "{{.Name}}" | while read -r network_name; do
        # Export network configuration to a backup file in the backup folder
        docker network inspect "$network_name" > "$backup_folder/network_${network_name}_backup.json"
    done

    log_message "INFO" "Network backup completed. Files are stored in: $PWD/$backup_folder"
    read -p "Press Enter to continue..."
    home
}

# Function to restore Docker networks
restore_networks() {
    log_message "INFO" "Restoring Docker networks..."
    # Check if the backup folder exists
    if [ -d "$backup_folder" ]; then
        # Iterate through network backup files in the backup folder
        for backup_file in "$backup_folder"/network_*_backup.json; do
            # Extract network name from the backup file name
            network_name=$(basename "$backup_file" | sed 's/network_\(.*\)_backup.json/\1/')

            # Check if the network already exists
            if [ -z "$(docker network ls --filter name="$network_name" -q)" ]; then
                # Read network configuration from JSON file
                driver=$(jq -r '.[0].Driver' "$backup_file")
                case "$driver" in
                    "bridge")
                        subnet=$(jq -r '.[0].IPAM.Config[0].Subnet' "$backup_file")
                        gateway=$(jq -r '.[0].IPAM.Config[0].Gateway' "$backup_file")
                        iprange=$(jq -r '.[0].IPAM.Config[0].IPRange' "$backup_file")
                        internal=$(jq -r '.[0].Internal' "$backup_file")
                        attachable=$(jq -r '.[0].Attachable' "$backup_file")
                        ingress=$(jq -r '.[0].Ingress' "$backup_file")

                        # Create the bridge network using the extracted configuration
                        docker network create \
                            --driver="$driver" \
                            --subnet="$subnet" \
                            --ip-range="$iprange" \
                            --gateway="$gateway" \
                            --internal="$internal" \
                            --attachable="$attachable" \
                            --ingress="$ingress" \
                            "$network_name"
                        ;;
                    "macvlan")
                        parent=$(jq -r '.[0].Options.parent' "$backup_file")

                        # Create the macvlan network using the extracted configuration
                        docker network create \
                            --driver="$driver" \
                            --subnet="$subnet" \
                            --ip-range="$iprange" \
                            --gateway="$gateway" \
                            --internal="$internal" \
                            --attachable="$attachable" \
                            --config-from="$config_from" \
                            --config-only="$config_only" \
                            --options="parent=$parent" \
                            "$network_name"
                        ;;
                    "null")
                        # Create the null network using the extracted configuration
                        docker network create \
                            --driver="$driver" \
                            --config-from="$config_from" \
                            --config-only="$config_only" \
                            "$network_name"
                        ;;
                    *)
                        log_message "WARN" "Unsupported driver '$driver' for network '$network_name'. Skipping restore."
                        continue
                        ;;
                esac

                log_message "INFO" "Network '$network_name' restored."
            else
                log_message "WARN" "Network '$network_name' already exists. Skipping restore."
            fi
        done
    else
        log_message "ERROR" "Backup folder '$backup_folder' not found. Please ensure that you have previously backed up your networks."
        read -p "Press Enter to continue..."
        home
    fi
    read -p "Press Enter to continue..."
    home
}


# Home menu
home() {
    while true; do
        echo -e "\033]0;Docker Network Toolbox [HOME]\007"
        clear
        echo -e "${blue_fg_strong}/ Home${reset}"
        echo "-------------------------------------"
        echo "What would you like to do?"
        echo "1. Backup Docker Networks"
        echo "2. Restore Docker Networks"
        echo "3. Exit"

        read -p "Choose Your Destiny: " home_choice

        # Default to choice 1 if no input is provided
        if [ -z "$home_choice" ]; then
            home_choice=1
        fi

        case $home_choice in
            1) backup_networks; break ;;
            2) restore_networks; break ;;
            3) exit ;;
            *) echo -e "${yellow_fg_strong}WARNING: Invalid number. Please insert a valid number.${reset}"
            read -p "Press Enter to continue..."
            home ;;
        esac
    done
}

# Start the home menu
home