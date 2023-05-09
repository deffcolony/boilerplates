#!/bin/bash

# Set the seafile container name and database container name
CONTAINER_NAME="seafile"
DB_CONTAINER_NAME="seafile-mariadb"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/seafile"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the seafile directory and database from the container to the backup directory
docker cp "$CONTAINER_NAME":/shared "$BACKUP_PATH"
docker exec "$DB_CONTAINER_NAME" sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$BACKUP_PATH/seafile-db.sql"

# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete