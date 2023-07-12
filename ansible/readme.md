## Installation - Ubuntu/Debian

To install Ansible on Ubuntu or Debian, you can follow these steps:

1. Add the Ansible repository

   ```bash
   sudo apt-add-repository ppa:ansible/ansible
   ```

2. Update the package list and install Ansible:

   ```bash
   sudo apt update && sudo apt install ansible
   ```

3. Configure the Ansible settings by navigating to the /etc/ansible/ directory and editing the ansible.cfg file:

   ```bash
   cd /etc/ansible/ && sudo nano ansible.cfg
   ```

Within the ansible.cfg file, add the following configuration:

```bash
[defaults]
inventory=hosts
host_key_checking=false
```

4. Edit the Ansible inventory file:

   ```bash
   sudo nano /etc/ansible/hosts
   ```

Within the hosts file, define your inventory with the appropriate IP addresses or hostnames. Adjust the IP addresses or hostnames, as well as the SSH username and password, according to your environment:

```bash
[master]
192.168.x.x # or hostname

[nodes]
192.168.x.x # or hostname


[master:vars]
ansible_ssh_user=master
ansible_ssh_pass=master

[nodes:vars]
ansible_ssh_user=insertusernamehere
ansible_ssh_pass=MysuporS3cretP@ass
```

5. Test the connection:

   ```bash
   ansible all -m ping
   ```
   
If the connection is successful, you should see a response indicating that the hosts are reachable.