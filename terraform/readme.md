## Installation - Ubuntu/Debian

To install Terraform on Ubuntu or Debian, you can follow these steps:

1. Install the `unzip` package:

   ```bash
   sudo apt install unzip
   ```

2. Download the HashiCorp GPG key and import it into the keyring:

   ```bash
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   ```

3. Add the HashiCorp repository to the APT sources list:

   ```bash
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   ```

4. Update the package list and install Terraform:

   ```bash
   sudo apt update && sudo apt install terraform
   ```



