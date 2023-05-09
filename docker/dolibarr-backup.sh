#!/bin/bash

# Set the dolibarr container name
CONTAINER_NAME="dolibarr"
DB_CONTAINER_NAME="dolibarr-mariadb"

# Set the backup directory
BACKUP_DIR="/home/gebruikersnaam/backups/dolibarr"

# Create a new directory for the backup
BACKUP_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH="$BACKUP_DIR/$BACKUP_DATE"
mkdir -p "$BACKUP_PATH"

# Copy the dolibarr directory's from the container to the backup directory
docker cp "$CONTAINER_NAME":/var/www/documents "$BACKUP_PATH"
docker cp "$CONTAINER_NAME":/var/www/html/custom "$BACKUP_PATH"
docker exec "$DB_CONTAINER_NAME" sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$BACKUP_PATH/dolibarr-db.sql"


# Compress the backup directory
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_DATE"

# Remove the uncompressed backup directory
rm -rf "$BACKUP_PATH"

# Prune old backups (keep the last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete