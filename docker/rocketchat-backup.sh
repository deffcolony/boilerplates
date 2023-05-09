#!/bin/bash

# Set the rocketchat container name and database container name
CONTAINER_NAME="rocketchat"
DB_CONTAINER_NAME="rocketchat-mongo"
DATABASE_NAME="rocketchat-db"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/rocketchat"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the rocketchat directory and database from the container to the backup directory
docker cp "$CONTAINER_NAME":/var/www/html "$BACKUP_PATH"
docker exec "$CONTAINER_NAME"_mongo mongodump --out "$BACKUP_PATH" --db "$DATABASE_NAME"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete