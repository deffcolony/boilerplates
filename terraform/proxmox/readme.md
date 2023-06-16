# Proxmox Terraform Configuration

This repository contains Terraform configuration files for managing Proxmox resources using Terraform.

## Prerequisites

Before you can use this Terraform configuration, ensure that you have the following:

- [Terraform](https://www.terraform.io/downloads.html) installed on your server.
- Access to a Proxmox server with appropriate permissions to create and manage resources.


## Configuration

The Terraform configurations in this repository include the following files:

- `credentials.auto.tfvars`: This file contains the configuration variables for connecting to your Proxmox instance. You need to provide values for the following variables:
  - `proxmox_api_url`: The URL of your Proxmox API.
  - `proxmox_api_token_id`: The API token ID for authentication.
  - `proxmox_api_token_secret`: The API token secret for authentication.

  **Note:** Make sure not to commit and push this file to a public repository as it contains sensitive information.

- `full-clone.tf`: This file defines the configuration for creating a new VM from a clone in Proxmox. It specifies various settings such as the target node, VM ID, name, description, CPU and memory settings, network configuration, and cloud-init settings. Modify this file to match your specific requirements for creating the VM.

- `provider.tf`: This file specifies the provider configuration for Proxmox. It defines the Proxmox API URL and the API token credentials used for authentication. You may optionally configure TLS verification in this file.

Modify these configuration files according to your Proxmox setup and requirements.

**Note:** It is recommended to review and customize these files carefully to ensure they align with your Proxmox environment and infrastructure needs.




## Getting Started

To get started with this Proxmox Terraform configuration, follow these steps:

1. Navigate to the cloned repository.

   ```shell
   cd boilerplates/terraform/proxmox
   ```

2. Open the `credentials.auto.tfvars` file and provide your Proxmox API credentials.

   ```shell
   cp credentials.auto.tfvars.example credentials.auto.tfvars
   nano credentials.auto.tfvars
   ```

   Replace the placeholder values with your actual Proxmox API URL, token ID, and token secret.

3. Review and customize the `full-clone.tf` file based on your requirements. This file defines the Proxmox full clone configuration. Update the VM settings, such as target node, VM ID, name, description, CPU, memory, network, etc., according to your needs.

4. Initialize the Terraform workspace.

   ```shell
   terraform init
   ```

5. Review the execution plan.

   ```shell
   terraform plan
   ```

   This will show you the planned changes that Terraform will apply to your Proxmox infrastructure based on the configuration files.

6. Apply the Terraform configuration.

   ```shell
   terraform apply
   ```

   Review the proposed changes and confirm by typing "yes" when prompted. Terraform will then create the specified resources in your Proxmox environment.

## Cleaning Up

To remove the created resources and destroy the Proxmox VM, you can use the following command:

```shell
terraform destroy
```

Review the planned changes and confirm the destruction by typing "yes" when prompted.

## Contributions

Contributions to this Proxmox Terraform configuration are welcome! If you find any issues or have suggestions for improvement, feel free to open an issue or submit a pull request.

## License

This Proxmox Terraform configuration is licensed under the [MIT License](LICENSE).

Feel free to customize and adapt the configuration to suit your specific needs.