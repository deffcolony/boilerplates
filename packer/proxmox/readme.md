# Packer Proxmox Templates

This directory contains Packer templates for building Proxmox virtual machine images. The templates are pre-configured for specific Ubuntu server versions and variations.

## Prerequisites

Before using these Packer templates, ensure that you have the following prerequisites in place:

- [Packer:](https://developer.hashicorp.com/packer/downloads) Install Packer on your local machine. Refer to the Packer website for installation instructions specific to your operating system.
- [Proxmox:](https://www.proxmox.com/en/downloads) Set up a Proxmox environment with valid credentials to access and manage Proxmox virtual machines.

## Contents

The following items are included in this directory:

- **ubuntu-server-focal-docker**: A Packer template for building an Ubuntu Server Focal image with Docker pre-installed.
- **ubuntu-server-focal**: A Packer template for building a standard Ubuntu Server Focal image.
- **ubuntu-server-jammy-docker**: A Packer template for building an Ubuntu Server Jammy image with Docker pre-installed.
- **ubuntu-server-jammy**: A Packer template for building a standard Ubuntu Server Jammy image.
- `credentials.pkr.hcl`: A file that contains the credentials or access details required for interacting with external services or resources during the image building process. Please ensure to keep this file secure and follow security best practices for handling sensitive credentials.


## Getting Started

To use these Packer proxmox templates, follow these steps:

1. Navigate to the cloned repository.

```shell
cd boilerplates/packer/proxmox
```

2. Choose the desired Packer template folder (ubuntu-server-focal-docker, ubuntu-server-focal, etc.) based on your requirements.

3. Customize the template files as needed, such as adjusting variables or adding provisioning scripts.

4. Execute the Packer build command for the chosen template.

```shell
packer build template-name.pkr.hcl
```

Replace `template-name.pkr.hcl` with the actual name of the template file you want to build.

5. Packer will start the image building process, and upon successful completion, the Proxmox virtual machine image will be created.

6. The built image can be used to provision new virtual machines in your Proxmox environment.

**Notes:**
- Ensure you have Packer before using these templates.
- Review and modify the template files according to your specific requirements and environment.
- Take necessary precautions to secure and protect any sensitive information in the `credentials.pkr.hcl` file.
- For more information on using Packer, refer to the Packer documentation.

**Important:** Use the Packer templates and scripts in this repository at your own risk. Review and test them thoroughly before using them in a production environment.