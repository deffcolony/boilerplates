#!/bin/bash

# Set the pihole container name
CONTAINER_NAME="pihole"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/pihole"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the pihole directory's from the container to the backup directory
docker cp "$CONTAINER_NAME":/etc/pihole "$BACKUP_PATH"
docker cp "$CONTAINER_NAME":/etc/dnsmasq.d "$BACKUP_PATH"
docker cp "$CONTAINER_NAME":/etc/lighttpd "$BACKUP_PATH"
docker cp "$CONTAINER_NAME":/var/www/html/pihole "$BACKUP_PATH"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete