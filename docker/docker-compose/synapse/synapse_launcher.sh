#!/bin/bash

# How to run this script:
# chmod +x synapse_launcher.sh && ./synapse_launcher.sh


set -euo pipefail

# --- Configuration ---
SYNAPSE_BASE_DIR=$(pwd) # Current directory where the script is run from
SYNAPSE_DATA_DIR="$SYNAPSE_BASE_DIR/data"
SYNAPSE_APPSERVICES_DIR="$SYNAPSE_DATA_DIR/appservices"
SYNAPSE_HOMESERVER_YAML="$SYNAPSE_DATA_DIR/homeserver.yaml"
SYNAPSE_BRIDGES_DIR="$SYNAPSE_BASE_DIR/bridges"
DOCKER_COMPOSE_CMD="docker compose"

# --- Script Config ---
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
green_bg="\033[42m"

# Foreground colors
yellow_fg_strong_fg="\033[33;1m" # Renamed to avoid conflict

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
        "OK")
            echo -e "${green_bg}[$current_time]${reset} ${green_fg_strong}[OK]${reset} $2"
            ;;
        *)
            echo -e "${blue_bg}[$current_time]${reset} ${blue_fg_strong}[DEBUG]${reset} $2"
            ;;
    esac
}


# Ensure root privileges (adjust if docker runs rootless or user is in docker group)
check_root() {
    # If docker doesn't require root, you might comment this out or adjust.
    # Check if user is in the docker group as an alternative for non-root docker usage
    # if [[ $EUID -ne 0 ]] && ! groups "$(whoami)" | grep -q '\bdocker\b'; then
    #     log_message "ERROR" "This script needs to be run as root or by a user in the 'docker' group."
    #     exit 1
    # elif [[ $EUID -ne 0 ]]; then
    #     log_message "INFO" "Running as non-root user in docker group."
    # else
    #    log_message "INFO" "Running as root."
    # fi

    # Simple root check for now, assuming root is needed for file operations outside docker volume mounts owned by root
     if [[ $EUID -ne 0 ]]; then
         log_message "ERROR" "This script might require root privileges for file operations. Trying to proceed..."
         # exit 1 # Exit if root is strictly required
     fi
}

# --- Helper Functions ---

# Function to check if essential commands exist
check_commands() {
    local missing_cmds=()
    if ! command -v docker &> /dev/null; then
        missing_cmds+=("docker")
    fi
    if ! command -v $DOCKER_COMPOSE_CMD &> /dev/null; then
         # Try alternative command name
         if command -v docker-compose &> /dev/null; then
             DOCKER_COMPOSE_CMD="docker-compose"
             log_message "INFO" "Using 'docker-compose' command."
         else
             missing_cmds+=("$DOCKER_COMPOSE_CMD or docker-compose")
         fi
    fi
     if ! command -v sed &> /dev/null; then
        missing_cmds+=("sed")
    fi
     if ! command -v grep &> /dev/null; then
        missing_cmds+=("grep")
    fi


    if [ ${#missing_cmds[@]} -ne 0 ]; then
        log_message "ERROR" "Missing required commands: ${missing_cmds[*]}. Please install them."
        exit 1
    fi
}

# Function to display placeholder message for unimplemented features
placeholder_function() {
    local bridge_name=$1
    log_message "WARN" "Installation/Uninstallation for $bridge_name is not yet implemented."
    read -p "Press Enter to continue..."
}

# Function to prompt for user input
get_user_input() {
    local prompt=$1
    local variable_name=$2
    local default_value=${3:-} # Optional default value

    if [[ -n "$default_value" ]]; then
         read -p "$prompt [$default_value]: " input
         eval "$variable_name=\"${input:-$default_value}\"" # Assign input or default
    else
         read -p "$prompt: " input
          while [[ -z "$input" ]]; do
                log_message "WARN" "Input cannot be empty."
                read -p "$prompt: " input
          done
         eval "$variable_name=\"$input\"" # Assign input
    fi
}

# Function to add registration file to homeserver.yaml
# Usage: add_registration_to_homeserver <registration_file_path_in_container> <bridge_name>
add_registration_to_homeserver() {
    local registration_path=$1
    local bridge_name=$2
    local registration_line="- $registration_path" # Note the space before '-'

    if [[ ! -f "$SYNAPSE_HOMESERVER_YAML" ]]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found!"
        return 1
    fi

    # Check if the app_service_config_files section exists
    if ! grep -q "^app_service_config_files:" "$SYNAPSE_HOMESERVER_YAML"; then
        log_message "INFO" "'app_service_config_files' section not found. Adding section and $bridge_name registration."
        # Append the section and the first entry
        # Use printf for better handling of newlines across systems
        printf "\napp_service_config_files:\n  %s\n" "$registration_line" >> "$SYNAPSE_HOMESERVER_YAML"
    else
        # Section exists, check if the specific registration line already exists
        # Use grep -F for fixed string matching and -x for whole line matching
        # Escape potential special characters in the path for grep if necessary, though `- F` helps
        # Add space before registration_line for matching indentation
        if ! grep -Fxq "  $registration_line" "$SYNAPSE_HOMESERVER_YAML"; then
            log_message "INFO" "Adding $bridge_name registration to $SYNAPSE_HOMESERVER_YAML."
            # Add the new line under the app_service_config_files line, preserving indentation
            # Using awk for more robust insertion after the marker
            awk -v line="  $registration_line" '
            /^[[:space:]]*app_service_config_files:[[:space:]]*$/ { print; print line; next }
            { print }
            ' "$SYNAPSE_HOMESERVER_YAML" > tmp_$$ && mv tmp_$$ "$SYNAPSE_HOMESERVER_YAML"
            # Alternative using sed (might be less robust if spacing varies)
            # sed -i "/^app_service_config_files:/a \ \ $registration_line" "$SYNAPSE_HOMESERVER_YAML"
        else
            log_message "INFO" "$bridge_name registration already exists in $SYNAPSE_HOMESERVER_YAML."
        fi
    fi
}

# Function to remove registration file from homeserver.yaml
# Usage: remove_registration_from_homeserver <registration_file_path_in_container> <bridge_name>
remove_registration_from_homeserver() {
    local registration_path=$1
    local bridge_name=$2
    local registration_line="- $registration_path" # Note the space before '-'

    if [[ ! -f "$SYNAPSE_HOMESERVER_YAML" ]]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found!"
        return 1
    fi

    # Check if the app_service_config_files section exists
    if ! grep -q "^app_service_config_files:" "$SYNAPSE_HOMESERVER_YAML"; then
        log_message "INFO" "'app_service_config_files' section not found in $SYNAPSE_HOMESERVER_YAML. Nothing to remove for $bridge_name."
        return 0
    fi

    # Check if the specific registration line exists
    if grep -Fxq "  $registration_line" "$SYNAPSE_HOMESERVER_YAML"; then
        log_message "INFO" "Removing $bridge_name registration from $SYNAPSE_HOMESERVER_YAML..."
        # Remove the exact line using sed
        sed -i "\|  $registration_line|d" "$SYNAPSE_HOMESERVER_YAML" || {
            log_message "ERROR" "Failed to remove $bridge_name registration from $SYNAPSE_HOMESERVER_YAML."
            return 1
        }

        # Check if app_service_config_files section is empty (only contains the header)
        if grep -A1 "^app_service_config_files:" "$SYNAPSE_HOMESERVER_YAML" | tail -n1 | grep -qE '^[[:space:]]*$'; then
            log_message "INFO" "'app_service_config_files' section is empty. Removing section."
            # Remove the app_service_config_files section entirely
            sed -i '/^app_service_config_files:/,/^[[:space:]]*$/d' "$SYNAPSE_HOMESERVER_YAML" || {
                log_message "WARN" "Failed to remove empty app_service_config_files section."
            }
        fi

        log_message "OK" "Removed $bridge_name registration from $SYNAPSE_HOMESERVER_YAML."
    else
        log_message "INFO" "$bridge_name registration not found in $SYNAPSE_HOMESERVER_YAML."
    fi

    return 0
}


########################################################################################
########################################################################################
####################### INSTALL FUNCTIONS  #############################################
########################################################################################
########################################################################################
install_mautrix_whatsapp() {
    local bot_username="whatsappbot"
    local bridge_name="whatsapp"
    local bridge_image="dock.mau.dev/mautrix/whatsapp:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [WhatsApp]\007"
    log_message "INFO" "Starting Mautrix-WhatsApp Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-whatsapp service is defined
    if ! grep -q "mautrix-whatsapp" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-whatsapp' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF
  mautrix-whatsapp:
    image: dock.mau.dev/mautrix/whatsapp:latest
    container_name: mautrix-whatsapp
    restart: unless-stopped
    ports:
      - "29318:29318"
    volumes:
      - $bridge_dir:/data
    depends_on:
      - synapse
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"


    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir"
    # Consider setting permissions if needed, although Docker volume usually handles this
    # chown <user>:<group> "$bridge_dir"


    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"

    # We need to mount the *absolute* path for the docker run command
    docker run --rm -v "$bridge_dir:/data" "$bridge_image"

    # Short sleep to ensure files are written before proceeding
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29318|address: http://mautrix-whatsapp:29318|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-whatsapp.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"




    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"

    # We need to mount the *absolute* path for the docker run command
    docker run --rm -v "$bridge_dir:/data" "$bridge_image"

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR"
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # Set permissions as specified - adjust if Synapse runs as a different user/group
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"


    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Start the bridge container ---
    log_message "INFO" "Starting mautrix-whatsapp container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" start mautrix-whatsapp || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Steps Reminder ---
    log_message "OK" ${green_fg_strong}"WhatsApp bridge installed successfully."${reset}
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login qr${reset}"
    log_message "INFO" "4. Scan the QR code displayed using WhatsApp mobile app (Linked Devices)."
    echo
    read -p "Press Enter to return to the main menu..."
}


install_mautrix_meta() {
    local bot_username="metabot"
    local bridge_name="meta"
    local bridge_image="dock.mau.dev/mautrix/meta:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Meta]\007"
    log_message "INFO" "Starting Mautrix-Meta Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-meta service is defined
    if ! grep -q "mautrix-meta" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-meta' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-meta:
    image: dock.mau.dev/mautrix/meta:latest
    container_name: mautrix-meta
    restart: unless-stopped
    volumes:
      - ./bridges/meta:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-meta:
    image: dock.mau.dev/mautrix/meta:latest
    container_name: mautrix-meta
    restart: unless-stopped
    volumes:
      - ./bridges/meta:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-meta service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29319|address: http://mautrix-meta:29319|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-discord.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-meta container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-meta container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Meta bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Meta."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_discord() {
    local bot_username="discordbot"
    local bridge_name="discord"
    local bridge_image="dock.mau.dev/mautrix/discord:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Discord]\007"
    log_message "INFO" "Starting Mautrix-Discord Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-discord service is defined
    if ! grep -q "mautrix-discord" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-discord' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-discord:
    image: dock.mau.dev/mautrix/discord:latest
    container_name: mautrix-discord
    restart: unless-stopped
    volumes:
      - ./bridges/discord:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-discord:
    image: dock.mau.dev/mautrix/discord:latest
    container_name: mautrix-discord
    restart: unless-stopped
    volumes:
      - ./bridges/discord:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-discord service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: https://matrix.example.com|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29334|address: http://mautrix-discord:29334|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-discord.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-discord container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-discord container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Discord bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Discord."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_telegram() {
    local bot_username="telegrambot"
    local bridge_name="telegram"
    local bridge_image="dock.mau.dev/mautrix/telegram:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Telegram]\007"
    log_message "INFO" "Starting Mautrix-Telegram Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-telegram service is defined
    if ! grep -q "mautrix-telegram" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-telegram' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-telegram:
    image: dock.mau.dev/mautrix/telegram:latest
    container_name: mautrix-telegram
    restart: unless-stopped
    volumes:
      - ./bridges/telegram:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-telegram:
    image: dock.mau.dev/mautrix/telegram:latest
    container_name: mautrix-telegram
    restart: unless-stopped
    volumes:
      - ./bridges/telegram:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-telegram service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: https://example.com|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29317|address: http://mautrix-telegram:29317|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-telegram.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-telegram container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-telegram container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Telegram bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Telegram."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_signal() {
    local bot_username="signalbot"
    local bridge_name="signal"
    local bridge_image="dock.mau.dev/mautrix/signal:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Signal]\007"
    log_message "INFO" "Starting Mautrix-Signal Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-signal service is defined
    if ! grep -q "mautrix-signal" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-signal' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-signal:
    image: dock.mau.dev/mautrix/signal:latest
    container_name: mautrix-signal
    restart: unless-stopped
    volumes:
      - ./bridges/signal:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-signal:
    image: dock.mau.dev/mautrix/signal:latest
    container_name: mautrix-signal
    restart: unless-stopped
    volumes:
      - ./bridges/signal:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-signal service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29328|address: http://mautrix-signal:29328|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-signal.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-signal container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-signal container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Signal bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Signal."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_twitter() {
    local bot_username="twitterbot"
    local bridge_name="twitter"
    local bridge_image="dock.mau.dev/mautrix/twitter:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Twitter]\007"
    log_message "INFO" "Starting Mautrix-Twitter Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-twitter service is defined
    if ! grep -q "mautrix-twitter" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-twitter' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-twitter:
    image: dock.mau.dev/mautrix/twitter:latest
    container_name: mautrix-twitter
    restart: unless-stopped
    volumes:
      - ./bridges/twitter:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-twitter:
    image: dock.mau.dev/mautrix/twitter:latest
    container_name: mautrix-twitter
    restart: unless-stopped
    volumes:
      - ./bridges/twitter:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-twitter service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29327|address: http://mautrix-twitter:29327|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-twitter.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-twitter container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-twitter container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Twitter bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Twitter."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_bluesky() {
    local bot_username="blueskybot"
    local bridge_name="bluesky"
    local bridge_image="dock.mau.dev/mautrix/bluesky:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Bluesky]\007"
    log_message "INFO" "Starting Mautrix-Bluesky Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-bluesky service is defined
    if ! grep -q "mautrix-bluesky" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-bluesky' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-bluesky:
    image: dock.mau.dev/mautrix/bluesky:latest
    container_name: mautrix-bluesky
    restart: unless-stopped
    volumes:
      - ./bridges/bluesky:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-bluesky:
    image: dock.mau.dev/mautrix/bluesky:latest
    container_name: mautrix-bluesky
    restart: unless-stopped
    volumes:
      - ./bridges/bluesky:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-bluesky service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29340|address: http://mautrix-bluesky:29340|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-bluesky.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-bluesky container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-bluesky container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Bluesky bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Bluesky."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_slack() {
    local bot_username="slackbot"
    local bridge_name="slack"
    local bridge_image="dock.mau.dev/mautrix/slack:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [Slack]\007"
    log_message "INFO" "Starting Mautrix-Slack Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-slack service is defined
    if ! grep -q "mautrix-slack" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-slack' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-slack:
    image: dock.mau.dev/mautrix/slack:latest
    container_name: mautrix-slack
    restart: unless-stopped
    volumes:
      - ./bridges/slack:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-slack:
    image: dock.mau.dev/mautrix/slack:latest
    container_name: mautrix-slack
    restart: unless-stopped
    volumes:
      - ./bridges/slack:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-slack service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29335|address: http://mautrix-slack:29335|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-slack.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-slack container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-slack container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}Slack bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with Slack."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_googlechat() {
    local bot_username="googlechatbot"
    local bridge_name="googlechat"
    local bridge_image="dock.mau.dev/mautrix/googlechat:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [GoogleChat]\007"
    log_message "INFO" "Starting Mautrix-GoogleChat Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-googlechat service is defined
    if ! grep -q "mautrix-googlechat" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-googlechat' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-googlechat:
    image: dock.mau.dev/mautrix/googlechat:latest
    container_name: mautrix-googlechat
    restart: unless-stopped
    volumes:
      - ./bridges/googlechat:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-googlechat:
    image: dock.mau.dev/mautrix/googlechat:latest
    container_name: mautrix-googlechat
    restart: unless-stopped
    volumes:
      - ./bridges/googlechat:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-googlechat service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: https://example.com|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29320|address: http://mautrix-googlechat:29320|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-googlechat.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-googlechat container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-googlechat container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}GoogleChat bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with GoogleChat."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_gmessages() {
    local bot_username="gmessagesbot"
    local bridge_name="gmessages"
    local bridge_image="dock.mau.dev/mautrix/gmessages:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [GMessages]\007"
    log_message "INFO" "Starting Mautrix-GMessages Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-gmessages service is defined
    if ! grep -q "mautrix-gmessages" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-gmessages' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-gmessages:
    image: dock.mau.dev/mautrix/gmessages:latest
    container_name: mautrix-gmessages
    restart: unless-stopped
    volumes:
      - ./bridges/gmessages:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-gmessages:
    image: dock.mau.dev/mautrix/gmessages:latest
    container_name: mautrix-gmessages
    restart: unless-stopped
    volumes:
      - ./bridges/gmessages:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-gmessages service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29336|address: http://mautrix-gmessages:29336|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-gmessages.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-gmessages container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-gmessages container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}GMessages bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with GMessages."
    echo
    read -p "Press Enter to return to the main menu..."
}

install_mautrix_gvoice() {
    local bot_username="gvoicebot"
    local bridge_name="gvoice"
    local bridge_image="dock.mau.dev/mautrix/gvoice:latest"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Installer [GVoice]\007"
    log_message "INFO" "Starting Mautrix-GVoice Bridge Installation..."

    # --- Check Prerequisites ---
    if [ -d "$bridge_dir" ]; then
        log_message "WARN" "Directory $bridge_dir already exists."
        read -p "Overwrite existing configuration? This will delete $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR after backup [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installation cancelled."
            return
        fi
        log_message "INFO" "Backing up existing $bridge_config_file..."
        if [ -f "$bridge_config_file" ]; then
            local backup_dir="$bridge_dir.bak-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir" || {
                log_message "WARN" "Failed to create backup directory $backup_dir. Proceeding without backup."
            }
            cp "$bridge_config_file" "$backup_dir/config.yaml" || {
                log_message "WARN" "Failed to backup $bridge_config_file. Proceeding with overwrite."
            }
            log_message "OK" "Backup created at $backup_dir/config.yaml."
        else
            log_message "INFO" "No existing $bridge_config_file to backup."
        fi
        log_message "INFO" "Deleting $SYNAPSE_BRIDGES_DIR and $SYNAPSE_APPSERVICES_DIR..."
        rm -rf "$SYNAPSE_BRIDGES_DIR" "$SYNAPSE_APPSERVICES_DIR" || {
            log_message "WARN" "Failed to delete $SYNAPSE_BRIDGES_DIR or $SYNAPSE_APPSERVICES_DIR. Proceeding with caution."
        }
    fi

    if [ ! -f "$SYNAPSE_BASE_DIR/docker-compose.yml" ]; then
        log_message "ERROR" "docker-compose.yml not found in $SYNAPSE_BASE_DIR."
        log_message "ERROR" "Please ensure you have a docker-compose.yml file."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Check if mautrix-gvoice service is defined
    if ! grep -q "mautrix-gvoice" "$SYNAPSE_BASE_DIR/docker-compose.yml"; then
        log_message "WARN" "'mautrix-gvoice' service not found in docker-compose.yml."
        log_message "INFO" "Suggested service configuration:"
        echo -e "${cyan_fg_strong}"
        cat << EOF

  mautrix-gvoice:
    image: dock.mau.dev/mautrix/gvoice:latest
    container_name: mautrix-gvoice
    restart: unless-stopped
    volumes:
      - ./bridges/gvoice:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
        echo -e "${reset}"
        read -p "Add this to docker-compose.yml and continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_message "INFO" "Please add the service and try again."
            read -p "Press Enter to return to menu..."
            return
        fi
        # Append the service configuration to docker-compose.yml
        echo -e "\n$(cat << EOF
  mautrix-gvoice:
    image: dock.mau.dev/mautrix/gvoice:latest
    container_name: mautrix-gvoice
    restart: unless-stopped
    volumes:
      - ./bridges/gvoice:/data
    depends_on:
      - synapse
    networks:
      - production
EOF
)" >> "$SYNAPSE_BASE_DIR/docker-compose.yml"
        log_message "INFO" "Added mautrix-gvoice service to docker-compose.yml."
    fi

    if [ ! -f "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML not found. Cannot configure Synapse."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Verify write permissions
    if [ ! -w "$SYNAPSE_HOMESERVER_YAML" ]; then
        log_message "ERROR" "$SYNAPSE_HOMESERVER_YAML is not writable. Check permissions."
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Get User Input ---
    get_user_input "Enter your Matrix homeserver domain (e.g., chat.example.com)" MATRIX_DOMAIN
    get_user_input "Enter your Matrix admin username (localpart only, e.g., 'admin')" MATRIX_ADMIN_USER
    local admin_mxid="@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN"
    log_message "INFO" "Configuring for domain '$MATRIX_DOMAIN' and admin '$admin_mxid'"

    # --- Create Directories ---
    log_message "INFO" "Creating bridge data directory: $bridge_dir"
    mkdir -p "$bridge_dir" || {
        log_message "ERROR" "Failed to create directory $bridge_dir."
        return
    }

    # --- Generate Config ---
    log_message "INFO" "Generating default config.yaml"
    docker run --rm -v "$bridge_dir:/data:z" "$bridge_image" || {
        log_message "ERROR" "Failed to generate config.yaml."
        return
    }

    # Short sleep to ensure files are written
    sleep 2
    log_message "INFO" "Generated config.yaml in $bridge_dir"

    # --- Modify config.yaml ---
    log_message "INFO" "Modifying $bridge_config_file per documentation..."
    # Backup config before modification
    cp "$bridge_config_file" "$bridge_config_file.bak" || log_message "WARN" "Failed to backup config.yaml"

    # Replace configuration values
    sed -i "s|address: http://example.localhost:8008|address: http://synapse:8008|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver address in $bridge_config_file"
    }
    sed -i "s|domain: example.com|domain: $MATRIX_DOMAIN|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update homeserver domain in $bridge_config_file"
    }
    sed -i "s|address: http://localhost:29338|address: http://mautrix-gvoice:29338|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice address in $bridge_config_file"
    }
    sed -i "s|hostname: 127.0.0.1|hostname: 0.0.0.0|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update appservice hostname in $bridge_config_file"
    }
    sed -i "s|type: postgres|type: sqlite3-fk-wal|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database type in $bridge_config_file"
    }
    sed -i "s|uri: postgres://user:password@host/database?sslmode=disable|uri: file:/data/mautrix-gvoice.db?_txlock=immediate|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update database URI in $bridge_config_file"
    }
    sed -i "s|\"example.com\": user|\"$MATRIX_DOMAIN\": user|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update permissions domain in $bridge_config_file"
    }
    sed -i "s|@admin:example.com\": admin|@$MATRIX_ADMIN_USER:$MATRIX_DOMAIN\": admin|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update admin permissions in $bridge_config_file"
    }
    sed -i "s|allow: false|allow: true|" "$bridge_config_file" || {
        log_message "ERROR" "Failed to update encryption setting in $bridge_config_file"
    }
    log_message "INFO" "Successfully modified $bridge_config_file"

    # --- Generate Registration ---
    log_message "INFO" "Generating registration.yaml"
    docker run --rm -v "$bridge_dir:/data" "$bridge_image" || {
        log_message "ERROR" "Failed to generate registration.yaml."
        return
    }

    sleep 2
    log_message "INFO" "Generated registration.yaml in $bridge_dir"

    # --- Handle registration.yaml ---
    log_message "INFO" "Setting up registration file..."
    mkdir -p "$SYNAPSE_APPSERVICES_DIR" || {
        log_message "ERROR" "Failed to create directory $SYNAPSE_APPSERVICES_DIR."
        return
    }
    cp "$bridge_registration_file" "$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml" || {
        log_message "ERROR" "Failed to copy registration.yaml to $SYNAPSE_APPSERVICES_DIR."
        return
    }

    # Set permissions
    chmod -R 755 "$SYNAPSE_APPSERVICES_DIR" || log_message "WARN" "Could not chmod $SYNAPSE_APPSERVICES_DIR. Check permissions."
    log_message "INFO" "registration.yaml copied to $SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    add_registration_to_homeserver "$container_registration_path" "$bridge_name"

    # --- Start the container ---
    log_message "INFO" "Starting mautrix-gvoice container..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" up -d || {
        log_message "ERROR" "Failed to start mautrix-gvoice container."
        return
    }

    # --- Final Steps Reminder ---
    log_message "OK" "${green_fg_strong}GVoice bridge installed successfully.${reset}"
    echo
    log_message "INFO" "${bold}Next Steps:${reset}"
    log_message "INFO" "1. Log in to a Matrix client (e.g., Element or Cinny)."
    log_message "INFO" "2. Start a direct chat with the bot: ${cyan_fg_strong}@${bot_username}:${MATRIX_DOMAIN}${reset}"
    log_message "INFO" "3. Send the message: ${cyan_fg_strong}login${reset}"
    log_message "INFO" "4. Follow the instructions provided by the bot to authenticate with GVoice."
    echo
    read -p "Press Enter to return to the main menu..."
}


########################################################################################
#                              MENU FUNCTIONS                                          #
########################################################################################

# Exit Function
exit_program() {
    clear
    echo "Bye!"
    exit 0
}

# --- Install Menu ---
install_menu() {
    clear
    echo -e "\033]0;Synapse Bridge Installer\007"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${blue_fg_strong}| Synapse Bridge Installer - Select Bridge to Install        |${reset}"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    echo -e "${white_fg_strong}  1) Mautrix-WhatsApp${reset}"
    echo -e "${white_fg_strong}  2) Mautrix-Meta (Facebook/Instagram)${reset}"
    echo -e "${white_fg_strong}  3) Mautrix-Discord${reset}"
    echo -e "${white_fg_strong}  4) Mautrix-Telegram${reset}"
    echo -e "${white_fg_strong}  5) Mautrix-Signal${reset}"
    echo -e "${white_fg_strong}  6) Mautrix-Twitter${reset}"
    echo -e "${white_fg_strong}  7) Mautrix-Bluesky${reset}"
    echo -e "${white_fg_strong}  8) Mautrix-Slack${reset}"
    echo -e "${white_fg_strong}  9) Mautrix-GoogleChat${reset}"
    echo -e "${white_fg_strong} 10) Mautrix-GMessages${reset}"
    echo -e "${white_fg_strong} 11) Mautrix-GVoice${reset}"
    echo -e "--------------------------------------------------------------"
    echo -e "  0) Back to Main Menu"
    echo -e "${blue_fg_strong}==============================================================${reset}"
    read -p ">> Enter choice: " choice

    case $choice in
        1) install_mautrix_whatsapp ;;
        2) install_mautrix_meta ;;
        3) install_mautrix_discord ;;
        4) install_mautrix_telegram ;;
        5) install_mautrix_signal ;;
        6) install_mautrix_twitter ;;
        7) install_mautrix_bluesky ;;
        8) install_mautrix_slack ;;
        9) install_mautrix_googlechat ;;
       10) install_mautrix_gmessages ;;
       11) install_mautrix_gvoice ;;
        0) main_menu ;;
        *)
            log_message "ERROR" "Invalid choice."
            read -p "Press Enter to continue..."
            install_menu ;;
    esac
    # Return to install menu after function completes unless it goes back explicitly
    install_menu
}

########################################################################################
########################################################################################
####################### UNINSTALL FUNCTIONS  ###########################################
########################################################################################
########################################################################################

# Function to display Danger Zone warning
display_danger_zone_warning() {
    echo
    echo -e "${red_bg}${bold}╔════ DANGER ZONE ═══════════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red_bg}${bold}║ WARNING: This action will PERMANENTLY DELETE all $bridge_name bridge data!         ║${reset}"
    echo -e "${red_bg}${bold}║ Ensure you have created backups if you want to retain any information.             ║${reset}"
    echo -e "${red_bg}${bold}║ This includes configurations, registration files, and bot user data.               ║${reset}"
    echo -e "${red_bg}${bold}╚════════════════════════════════════════════════════════════════════════════════════╝${reset}"
    echo
}

uninstall_mautrix_whatsapp() {
    local bot_username="whatsappbot"
    local bridge_name="whatsapp"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [WhatsApp]\007"


    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-WhatsApp bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-WhatsApp Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-whatsapp" >/dev/null; then
        log_message "INFO" "Stopping mautrix-whatsapp Docker container..."
        docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" stop mautrix-whatsapp || {
            log_message "WARN" "Failed to stop mautrix-whatsapp container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-whatsapp" >/dev/null; then
        log_message "INFO" "Removing mautrix-whatsapp Docker container..."
        docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" rm mautrix-whatsapp || {
            log_message "WARN" "Failed to remove mautrix-whatsapp container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-WhatsApp bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}


uninstall_mautrix_meta() {
    local bot_username="metabot"
    local bridge_name="meta"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Meta]\007"


    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Meta bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Meta Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-meta" >/dev/null; then
        log_message "INFO" "Stopping mautrix-meta Docker container..."
        docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" stop mautrix-meta || {
            log_message "WARN" "Failed to stop mautrix-meta container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-meta" >/dev/null; then
        log_message "INFO" "Removing mautrix-meta Docker container..."
        docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" rm mautrix-meta || {
            log_message "WARN" "Failed to remove mautrix-meta container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Meta bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_discord() {
    local bot_username="discordbot"
    local bridge_name="discord"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Discord]\007"


    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Discord bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Discord Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-discord" >/dev/null; then
        log_message "INFO" "Stopping mautrix-discord Docker container..."
        docker stop mautrix-discord || {
            log_message "WARN" "Failed to stop mautrix-discord container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-discord" >/dev/null; then
        log_message "INFO" "Removing mautrix-discord Docker container..."
        docker rm mautrix-discord || {
            log_message "WARN" "Failed to remove mautrix-discord container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Discord bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_telegram() {
    local bot_username="telegrambot"
    local bridge_name="telegram"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Telegram]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Telegram bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Telegram Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-telegram" >/dev/null; then
        log_message "INFO" "Stopping mautrix-telegram Docker container..."
        docker stop mautrix-telegram || {
            log_message "WARN" "Failed to stop mautrix-telegram container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-telegram" >/dev/null; then
        log_message "INFO" "Removing mautrix-telegram Docker container..."
        docker rm mautrix-telegram || {
            log_message "WARN" "Failed to remove mautrix-telegram container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Telegram bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_signal() {
    local bot_username="signalbot"
    local bridge_name="signal"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Signal]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Signal bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Signal Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-signal" >/dev/null; then
        log_message "INFO" "Stopping mautrix-signal Docker container..."
        docker stop mautrix-signal || {
            log_message "WARN" "Failed to stop mautrix-signal container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-signal" >/dev/null; then
        log_message "INFO" "Removing mautrix-signal Docker container..."
        docker rm mautrix-signal || {
            log_message "WARN" "Failed to remove mautrix-signal container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Signal bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_twitter() {
    local bot_username="twitterbot"
    local bridge_name="twitter"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Twitter]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Twitter bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Twitter Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-twitter" >/dev/null; then
        log_message "INFO" "Stopping mautrix-twitter Docker container..."
        docker stop mautrix-twitter || {
            log_message "WARN" "Failed to stop mautrix-twitter container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-twitter" >/dev/null; then
        log_message "INFO" "Removing mautrix-twitter Docker container..."
        docker rm mautrix-twitter || {
            log_message "WARN" "Failed to remove mautrix-twitter container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Twitter bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_bluesky() {
    local bot_username="blueskybot"
    local bridge_name="bluesky"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Bluesky]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Bluesky bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Bluesky Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-bluesky" >/dev/null; then
        log_message "INFO" "Stopping mautrix-bluesky Docker container..."
        docker stop mautrix-bluesky || {
            log_message "WARN" "Failed to stop mautrix-bluesky container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-bluesky" >/dev/null; then
        log_message "INFO" "Removing mautrix-bluesky Docker container..."
        docker rm mautrix-bluesky || {
            log_message "WARN" "Failed to remove mautrix-bluesky container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Bluesky bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_slack() {
    local bot_username="slackbot"
    local bridge_name="slack"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [Slack]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-Slack bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-Slack Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-slack" >/dev/null; then
        log_message "INFO" "Stopping mautrix-slack Docker container..."
        docker stop mautrix-slack || {
            log_message "WARN" "Failed to stop mautrix-slack container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-slack" >/dev/null; then
        log_message "INFO" "Removing mautrix-slack Docker container..."
        docker rm mautrix-slack || {
            log_message "WARN" "Failed to remove mautrix-slack container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-Slack bridge uninstalled successfully.${reset}"
    read -p "Press Enter to the main menu..."
}

uninstall_mautrix_googlechat() {
    local bot_username="googlechatbot"
    local bridge_name="googlechat"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [GoogleChat]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-GoogleChat bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-GoogleChat Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-googlechat" >/dev/null; then
        log_message "INFO" "Stopping mautrix-googlechat Docker container..."
        docker stop mautrix-googlechat || {
            log_message "WARN" "Failed to stop mautrix-googlechat container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-googlechat" >/dev/null; then
        log_message "INFO" "Removing mautrix-googlechat Docker container..."
        docker rm mautrix-googlechat || {
            log_message "WARN" "Failed to remove mautrix-googlechat container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-GoogleChat bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_gmessages() {
    local bot_username="gmessagesbot"
    local bridge_name="gmessages"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [GMessages]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-GMessages bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-GMessages Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-gmessages" >/dev/null; then
        log_message "INFO" "Stopping mautrix-gmessages Docker container..."
        docker stop mautrix-gmessages || {
            log_message "WARN" "Failed to stop mautrix-gmessages container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-gmessages" >/dev/null; then
        log_message "INFO" "Removing mautrix-gmessages Docker container..."
        docker rm mautrix-gmessages || {
            log_message "WARN" "Failed to remove mautrix-gmessages container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-GMessages bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

uninstall_mautrix_gvoice() {
    local bot_username="gvoicebot"
    local bridge_name="gvoice"
    local bridge_dir="$SYNAPSE_BRIDGES_DIR/$bridge_name"
    local bridge_config_file="$bridge_dir/config.yaml"
    local bridge_registration_file="$bridge_dir/registration.yaml"
    local container_registration_path="/data/appservices/$bridge_name-registration.yaml"
    local appservice_registration="$SYNAPSE_APPSERVICES_DIR/$bridge_name-registration.yaml"

    clear
    echo -e "\033]0;Synapse Bridge Uninstaller [GVoice]\007"

    # --- Check if Bridge is Installed ---
    if [ ! -d "$bridge_dir" ] && [ ! -f "$appservice_registration" ]; then
        log_message "ERROR" "Mautrix-GVoice bridge is already uninstalled!"
        read -p "Press Enter to return to menu..."
        return
    fi

    # --- Confirm Uninstallation ---
    display_danger_zone_warning
    echo -n -e "${yellow_fg_strong}Are you sure you want to proceed? [Y/N]: ${reset}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_message "INFO" "Uninstallation cancelled."
        read -p "Press Enter to return to menu..."
        return
    fi

    log_message "INFO" "Starting Mautrix-GVoice Bridge Uninstallation..."

    # --- Stop the Docker Service ---
    if docker ps -q --filter "name=mautrix-gvoice" >/dev/null; then
        log_message "INFO" "Stopping mautrix-gvoice Docker container..."
        docker stop mautrix-gvoice || {
            log_message "WARN" "Failed to stop mautrix-gvoice container. Proceeding with uninstallation."
        }
    fi

    # --- Remove the Docker Service ---
    if docker ps -a -q --filter "name=mautrix-gvoice" >/dev/null; then
        log_message "INFO" "Removing mautrix-gvoice Docker container..."
        docker rm mautrix-gvoice || {
            log_message "WARN" "Failed to remove mautrix-gvoice container."
        }
    fi

    # --- Remove Bridge Files ---
    log_message "INFO" "Removing bridge data directory: $bridge_dir..."
    rm -rf "$bridge_dir" || {
        log_message "WARN" "Failed to remove $bridge sizeable_dir. Please check permissions and remove manually."
    }

    log_message "INFO" "Removing registration file: $appservice_registration..."
    rm -f "$appservice_registration" || {
        log_message "WARN" "Failed to remove $appservice_registration. Please check permissions and remove manually."
    }

    # --- Update homeserver.yaml ---
    log_message "INFO" "Updating $SYNAPSE_HOMESERVER_YAML..."
    remove_registration_from_homeserver "$container_registration_path" "$bridge_name"

    # --- Restart Synapse to Apply Changes ---
    log_message "INFO" "Restarting Synapse to apply changes..."
    docker compose -f "$SYNAPSE_BASE_DIR/docker-compose.yml" restart synapse || {
        log_message "WARN" "Failed to restart Synapse. Please restart manually to apply changes."
    }

    # --- Final Message ---
    log_message "OK" "${green_fg_strong}Mautrix-GVoice bridge uninstalled successfully.${reset}"
    read -p "Press Enter to return to the main menu..."
}

########################################################################################
####################### UNINSTALL MENU  ################################################
########################################################################################
uninstall_menu() {
    clear
    echo -e "\033]0;Synapse Bridge Uninstaller\007"
    echo -e "${red_fg_strong}==============================================================${reset}"
    echo -e "${red_fg_strong}| Synapse Bridge Uninstaller - Select Bridge to Uninstall    |${reset}"
    echo -e "${red_fg_strong}==============================================================${reset}"
    echo -e "${white_fg_strong}  1) Mautrix-WhatsApp${reset}"
    echo -e "${white_fg_strong}  2) Mautrix-Meta (Facebook/Instagram)${reset}"
    echo -e "${white_fg_strong}  3) Mautrix-Discord${reset}"
    echo -e "${white_fg_strong}  4) Mautrix-Telegram${reset}"
    echo -e "${white_fg_strong}  5) Mautrix-Signal${reset}"
    echo -e "${white_fg_strong}  6) Mautrix-Twitter${reset}"
    echo -e "${white_fg_strong}  7) Mautrix-Bluesky${reset}"
    echo -e "${white_fg_strong}  8) Mautrix-Slack${reset}"
    echo -e "${white_fg_strong}  9) Mautrix-GoogleChat${reset}"
    echo -e "${white_fg_strong} 10) Mautrix-GMessages${reset}"
    echo -e "${white_fg_strong} 11) Mautrix-GVoice${reset}"
    echo -e "--------------------------------------------------------------"
    echo -e "  0) Back to Main Menu"
    echo -e "${red_fg_strong}==============================================================${reset}"
    read -p ">> Enter choice: " choice

    case $choice in
        1) uninstall_mautrix_whatsapp ;;
        2) uninstall_mautrix_meta ;;
        3) uninstall_mautrix_discord ;;
        4) uninstall_mautrix_telegram ;;
        5) uninstall_mautrix_signal ;;
        6) uninstall_mautrix_twitter ;;
        7) uninstall_mautrix_bluesky ;;
        8) uninstall_mautrix_slack ;;
        9) uninstall_mautrix_googlechat ;;
       10) uninstall_mautrix_gmessages ;;
       11) uninstall_mautrix_gvoice ;;
        0) main_menu ;;
        *)
            log_message "ERROR" "Invalid choice."
            read -p "Press Enter to continue..."
            install_menu ;;
    esac
    # Return to uninstall menu after function completes unless it goes back explicitly
    uninstall_menu
}


# --- Main Menu ---
main_menu() {
    clear
    cd "$SYNAPSE_BASE_DIR" # Ensure we are in the correct directory
    echo -e "\033]0;Synapse Bridge Manager\007"
    echo -e "${green_fg_strong}==============================================================${reset}"
    echo -e "${green_fg_strong}| Synapse Matrix Bridge Manager                              |${reset}"
    echo -e "${green_fg_strong}==============================================================${reset}"
    echo -e "${cyan_fg_strong}  1) Install a Bridge${reset}"
    echo -e "${yellow_fg_strong_fg}  2) Uninstall a Bridge${reset}"
    echo -e "--------------------------------------------------------------"
    echo -e "  0) Exit"
    echo -e "${green_fg_strong}==============================================================${reset}"
    read -p ">> Enter choice: " choice

    case $choice in
        1) install_menu ;;
        2) uninstall_menu ;;
        0) exit_program ;;
        *)
            log_message "ERROR" "Invalid choice."
            read -p "Press Enter to continue..."
            main_menu ;;
    esac
     # Return to main menu after function completes unless it goes back explicitly
     main_menu
}

# --- Script Entry Point ---
check_root
check_commands
main_menu