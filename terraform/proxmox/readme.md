```
# Proxmox Terraform Configuration

This repository contains Terraform configuration files for managing Proxmox resources using Terraform.

## Prerequisites

Before you can use this Terraform configuration, ensure that you have the following:

- [Terraform](https://www.terraform.io/downloads.html) installed on your server.
- Access to a Proxmox server with appropriate permissions to create and manage resources.

## Getting Started

To get started with this Proxmox Terraform configuration, follow these steps:

1. Clone this repository to your server.

   ```shell
   git clone https://github.com/deffcolony/proxmox-terraform.git
   ```

2. Navigate to the cloned repository.

   ```shell
   cd proxmox-terraform
   ```

3. Open the `credentials.auto.tfvars` file and provide your Proxmox API credentials.

   ```shell
   cp credentials.auto.tfvars.example credentials.auto.tfvars
   nano credentials.auto.tfvars
   ```

   Replace the placeholder values with your actual Proxmox API URL, token ID, and token secret.

4. Review and customize the `full-clone.tf` file based on your requirements. This file defines the Proxmox full clone configuration. Update the VM settings, such as target node, VM ID, name, description, CPU, memory, network, etc., according to your needs.

5. Initialize the Terraform workspace.

   ```shell
   terraform init
   ```

6. Review the execution plan.

   ```shell
   terraform plan
   ```

   This will show you the planned changes that Terraform will apply to your Proxmox infrastructure based on the configuration files.

7. Apply the Terraform configuration.

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
```