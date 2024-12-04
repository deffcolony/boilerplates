# Nextcloud Launcher guide

This guide provides the steps to install and uninstall Nextcloud using custom scripts.

## Prerequisites

- Ensure you have Docker and Docker Compose installed on your server.
- The scripts below will need to be run with `sudo` for the necessary permissions.

## Nextcloud Launcher

To Start the Nextcloud Launcher, you can run the `nextcloud_launcher.sh` script.

### Steps:

1. First, make the script executable:
    ```bash
    sudo chmod +x nextcloud_launcher.sh
    ```

2. Run the installation script:
    ```bash
    sudo ./nextcloud_launcher.sh
    ```

Alternatively, you can run both commands in one line:
```bash
sudo chmod +x nextcloud_launcher.sh && sudo ./nextcloud_launcher.sh
```
