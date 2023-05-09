#!/bin/bash

# Set the authelia container name and database container name
CONTAINER_NAME="authelia"
DB_CONTAINER_NAME="authelia-redis"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/authelia"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the authelia directory and database from the container to the backup directory
docker cp "$CONTAINER_NAME":/config "$BACKUP_PATH"
docker cp "$DB_CONTAINER_NAME":/data "$BACKUP_PATH"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete