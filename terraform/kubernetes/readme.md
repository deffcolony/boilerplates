# Kubernetes Terraform Configuration

This repository contains Terraform configurations to deploy and manage resources on a Kubernetes cluster.

## Prerequisites

Before using these Terraform configurations, ensure that you have the following prerequisites:

- [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
- Access to a Kubernetes cluster where you have permission to create and manage resources.

## Contents

The Terraform configurations in this repository include the following files:

- `deployment.tf`: Defines the Kubernetes deployments to create on the cluster.
- `ingress.tf`: Configures the Kubernetes Ingress resources for routing external traffic to the deployed services.
- `provider.tf`: Specifies the provider configuration for Kubernetes.
- `secret-flexible.tf`: Manages flexible Kubernetes secrets containing sensitive information.
- `secret-hardcoded.tf`: Manages hardcoded Kubernetes secrets containing sensitive information.
- `service.tf`: Defines the Kubernetes services to expose and access the deployed applications.

Modify these configuration files to match your specific requirements.



## Getting Started

To deploy the Kubernetes resources, follow these steps:

1. Navigate to the cloned repository.

   ```shell
   cd boilerplates/terraform/kubernetes
   ```

2. Initialize the Terraform workspace.

   ```shell
   terraform init
   ```

3. Review the execution plan.

   ```shell
   terraform plan
   ```

   This will show you the planned changes that Terraform will apply to your kubernetes infrastructure based on the configuration files.

4. Apply the Terraform configuration.

   ```shell
   terraform apply
   ```

Terraform will prompt for confirmation before creating any resources. Enter "yes" to proceed.


5. Wait for Terraform to provision the resources. Once completed, it will display the output with any relevant information.

6. You can now access and manage your deployed applications on the Kubernetes cluster.


## Cleaning Up

To remove the deployed Kubernetes resources, run the following command:

```shell
terraform destroy
```

Terraform will prompt for confirmation before destroying any resources. Enter "yes" to proceed.

Note: This will permanently delete all the resources created by Terraform, so use it with caution.


## Contributions

Contributions to this Kubernetes Terraform configuration are welcome! If you find any issues or have suggestions for improvement, feel free to open an issue or submit a pull request.

## License

This Kubernetes Terraform configuration is licensed under the [MIT License](LICENSE).

Feel free to customize and adapt the configuration to suit your specific needs.