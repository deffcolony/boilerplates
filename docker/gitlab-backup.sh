#!/bin/bash

# Set the gitlab container name
CONTAINER_NAME="gitlab-runner"
WEB_CONTAINER_NAME="gitlab-ce"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/gitlab"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the gitlab directory's from the container to the backup directory
docker cp "$CONTAINER_NAME":/etc/gitlab-runner "$BACKUP_PATH"
docker cp "$WEB_CONTAINER_NAME":/etc/gitlab "$BACKUP_PATH"
docker cp "$WEB_CONTAINER_NAME":/var/log/gitlab "$BACKUP_PATH"
docker cp "$WEB_CONTAINER_NAME":/var/opt/gitlab "$BACKUP_PATH"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete