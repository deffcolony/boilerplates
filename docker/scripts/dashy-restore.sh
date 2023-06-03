#!/bin/bash

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Set the dashy container name
CONTAINER_NAME="dashy"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/docker/backups/dashy"

# Set the directory where the host volumes are mounted
HOST_VOLUME_DIR="/home/gebruikersnaam/docker/dashy"

# List available backups
echo -e "${YELLOW}Please choose a backup you want to restore:${NC}"
BACKUP_FILES=( $(ls -1 "$BACKUP_DIR") )
for i in "${!BACKUP_FILES[@]}"; do
  echo "$((i+1)). ${BACKUP_FILES[$i]}"
done

# Set the maximum number of attempts
MAX_ATTEMPTS=3
attempts=0

while true; do
  # Prompt user to select a backup file
  read -p "Enter backup number: " CHOICE

  # Check if backup file number is not empty and is valid
  if [ -z "$CHOICE" ]; then
    echo "Backup file number cannot be empty."
  elif ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#BACKUP_FILES[@]}" ]; then
    echo "Invalid number. Please choose a number between 1 and ${#BACKUP_FILES[@]}."
  else
    # Set the backup file path
    BACKUP_FILE_PATH="$BACKUP_DIR/${BACKUP_FILES[$CHOICE-1]}"

    # Check if the selected backup file exists
    if [ ! -f "$BACKUP_FILE_PATH" ]; then
      echo "Backup file not found. Aborting..."
      exit 1
    fi

    # Extract the backup to a temporary directory
    TEMP_DIR="/tmp/dashy-restore"
    mkdir -p "$TEMP_DIR"
    tar -xzf "$BACKUP_FILE_PATH" -C "$TEMP_DIR"

    # Stop the dashy container
    docker stop "$CONTAINER_NAME"

    # Copy the backup files to the host volume directory
    cp -r "$TEMP_DIR/$(basename "$BACKUP_FILE_PATH" .tar.gz)/public/conf.yml" "$HOST_VOLUME_DIR"
    cp -r "$TEMP_DIR/$(basename "$BACKUP_FILE_PATH" .tar.gz)/icons" "$HOST_VOLUME_DIR"
    
    # Remove the temporary directory
    rm -rf "$TEMP_DIR"
    
    # Start the dashy container
    docker start "$CONTAINER_NAME"

    echo "Restore completed successfully."
    break
  fi

  # Increment the number of attempts
  attempts=$((attempts+1))

  # Check if the maximum number of attempts has been reached
  if [ "$attempts" -ge "$MAX_ATTEMPTS" ]; then
    echo "Yeah... I am aborting the script. Too many invalid attempts."
    exit 1
  fi
done
