# Nextcloud Installation and Uninstallation Guide

This guide provides the steps to install and uninstall Nextcloud using custom scripts.

## Prerequisites

- Ensure you have Docker and Docker Compose installed on your server.
- The scripts below will need to be run with `sudo` for the necessary permissions.

## Install Nextcloud

To install Nextcloud, you can run the `install_nextcloud.sh` script. This will configure Nextcloud and its associated services.

### Steps:

1. First, make the script executable:
    ```bash
    sudo chmod +x install_nextcloud.sh
    ```

2. Run the installation script:
    ```bash
    sudo ./install_nextcloud.sh
    ```

Alternatively, you can run both commands in one line:
```bash
sudo chmod +x install_nextcloud.sh && sudo ./install_nextcloud.sh
```

## Uninstall Nextcloud
To uninstall Nextcloud and remove its services, you can run the `uninstall_nextcloud.sh` script.

### Steps:

1. First, make the script executable:
    ```bash
    sudo chmod +x uninstall_nextcloud.sh
    ```

2. Run the installation script:
    ```bash
    sudo ./uninstall_nextcloud.sh
    ```

Alternatively, you can run both commands in one line:
```bash
sudo chmod +x uninstall_nextcloud.sh && sudo ./uninstall_nextcloud.sh
```
