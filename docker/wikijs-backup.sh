#!/bin/bash

# Set the wikijs container name
CONTAINER_NAME="wikijs"
DB_CONTAINER_NAME="wikijs-postgres"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/wikijs"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the wikijs directory's from the container to the backup directory
docker exec "$DB_CONTAINER_NAME" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -W "$POSTGRES_PASSWORD" > "$BACKUP_PATH/wikijs-db.dump"


# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete