#!/bin/bash

# Set the website01-nginx container name
CONTAINER_NAME="website01-nginx"

# Set the backup directory
BACKUP_DIR="/media/disk/hdd01/backups/website01-nginx"

# List available backups
echo "Available backups:"
ls -1 "$BACKUP_DIR"

# Set the maximum number of attempts
MAX_ATTEMPTS=3

# Prompt user to select a backup file
for (( i=1; i<=$MAX_ATTEMPTS; i++ ))
do
  read -p "Enter the name of the backup file to restore: " BACKUP_FILE

  # Check if backup file name is not empty
  if [ -z "$BACKUP_FILE" ]; then
    echo "Backup file name cannot be empty."
    if [ $i -eq $MAX_ATTEMPTS ]; then
      echo "Yeah... I am aborting the script."
      exit 1
    fi
  else
    # Set the backup file path
    BACKUP_FILE_PATH="$BACKUP_DIR/$BACKUP_FILE"

    # Check if the selected backup file exists
    if [ ! -f "$BACKUP_FILE_PATH" ]; then
      echo "WARNING! Invalid backup name."
      if [ $i -eq $MAX_ATTEMPTS ]; then
        echo "This is invalid... I am aborting the script."
        exit 1
      fi
    else
      break
    fi
  fi
done

# Extract the backup to a temporary directory
mkdir -p /tmp/website01-nginx-restore
tar -xzf "$BACKUP_FILE_PATH" -C /tmp/website01-nginx-restore/

# Restore the website01-nginx directory's from the backup directory
docker cp /tmp/website01-nginx-restore/ "$CONTAINER_NAME":/usr/share/nginx/


# Remove the temporary directory
rm -rf /tmp/website01-nginx-restore

echo "Restore completed successfully."