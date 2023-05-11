#!/bin/bash

# Set the website01-nginx container name
CONTAINER_NAME="website01-nginx"

# Stop the website01-nginx container
docker stop "$CONTAINER_NAME"

# Set the backup directory
BACKUP_DIR="/media/disk/hdd01/backups/website01-nginx"

# List available backups
echo "Please choose the backup you wish to restore:"
BACKUP_FILES=( $(ls -1 "$BACKUP_DIR") )
for i in "${!BACKUP_FILES[@]}"; do
  echo "$((i+1)). ${BACKUP_FILES[$i]}"
done

# Set the maximum number of attempts
MAX_ATTEMPTS=3
attempts=0

while true; do
  # Prompt user to select a backup file
  read -p "Enter the number of the backup file to restore: " CHOICE

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
    TEMP_DIR="/tmp/website01-nginx-restore"
    mkdir -p "$TEMP_DIR"
    tar -xzf "$BACKUP_FILE_PATH" -C "$TEMP_DIR"


    # Restore the website01-nginx directory's from the backup directory
    docker cp "$TEMP_DIR/$(basename "$BACKUP_FILE_PATH" .tar.gz)/html" "$CONTAINER_NAME":/usr/share/nginx/
    docker cp "$TEMP_DIR/$(basename "$BACKUP_FILE_PATH" .tar.gz)/nginx.conf" "$CONTAINER_NAME":/etc/nginx/
    
    # Remove the temporary directory
    rm -rf "$TEMP_DIR"
    
    # Start the website01-nginx container
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
