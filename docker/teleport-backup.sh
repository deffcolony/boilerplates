#!/bin/bash

# Set the teleport container name
CONTAINER_NAME="teleport"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/teleport"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the teleport directory's from the container to the backup directory
docker cp "$CONTAINER_NAME":/etc/teleport "$BACKUP_PATH"
docker cp "$CONTAINER_NAME":/var/lib/teleport "$BACKUP_PATH"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete