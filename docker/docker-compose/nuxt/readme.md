# Nuxt Launcher guide

This guide provides the steps to install and uninstall Nuxt using custom scripts.

## Prerequisites

- Ensure you have node.js, Docker and Docker Compose installed on your server.
- The scripts below will need to be run with `sudo` for the necessary permissions.

## Nuxt Launcher

To Start the Nuxt Launcher, you can run the `nuxt_launcher.sh` script.

### Steps:

1. First, make the script executable:
    ```bash
    sudo chmod +x nuxt_launcher.sh
    ```

2. Run the installation script:
    ```bash
    sudo ./nuxt_launcher.sh
    ```

Alternatively, you can run both commands in one line:
```bash
sudo chmod +x nuxt_launcher.sh && sudo ./nuxt_launcher.sh
```
