#!/bin/bash

# Set the wordpress01 container name
CONTAINER_NAME="wordpress01"
DB_CONTAINER_NAME="wordpress01-mysql"


# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/wordpress01"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the wordpress01 directory's from the container to the backup directory
docker cp "$CONTAINER_NAME":/var/www/html "$BACKUP_PATH"
docker exec "$DB_CONTAINER_NAME" mysqldump -u "$MYSQL_USER" -p "$MYSQL_PASSWORD" "$MYSQL_DATABASE" > "$BACKUP_PATH/wordpress01-db.sql"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete