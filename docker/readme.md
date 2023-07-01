

# Class A (10.0.0.0) IP plan template

These subnet templates are designed to help you organize your Docker services on your server using the Class A Network (10.0.0.0). Each subnet corresponds to a specific category of services, making it easy to group and manage your containers. Enjoy self-hosting your Docker services with an efficient IP plan

1. Kubernetes & Management
   - Subnet: 10.0.0.0/24
   - Range: 10.0.0.1 - 10.0.0.254
   - Gateway: 10.0.0.1
   - Broadcast: 10.0.0.255
   - Available IP addresses: 254

2. Monitoring & Security 
   - Subnet: 10.0.1.0/24
   - Range: 10.0.1.1 - 10.0.1.254
   - Gateway: 10.0.1.1
   - Broadcast: 10.0.1.255
   - Available IP addresses: 254

3. Communication 
   - Subnet: 10.0.2.0/24
   - Range: 10.0.2.1 - 10.0.2.254
   - Gateway: 10.0.2.1
   - Broadcast: 10.0.2.255
   - Available IP addresses: 254

4. Productivity & Web Server 
   - Subnet: 10.0.3.0/24
   - Range: 10.0.3.1 - 10.0.3.254
   - Gateway: 10.0.3.1
   - Broadcast: 10.0.3.255
   - Available IP addresses: 254

5. Media Servers
   - Subnet: 10.0.4.0/24
   - Range: 10.0.4.1 - 10.0.4.254
   - Gateway: 10.0.4.1
   - Broadcast: 10.0.4.255
   - Available IP addresses: 254

6. File Share
   - Subnet: 10.0.5.0/24
   - Range: 10.0.5.1 - 10.0.5.254
   - Gateway: 10.0.5.1
   - Broadcast: 10.0.5.255
   - Available IP addresses: 254

7. Home Dashboards 
   - Subnet: 10.0.6.0/24
   - Range: 10.0.6.1 - 10.0.6.254
   - Gateway: 10.0.6.1
   - Broadcast: 10.0.6.255
   - Available IP addresses: 254


# Class B (172.16.0.0) IP plan template

1. Kubernetes & Management
   - Subnet: 172.16.0.0/24
   - Range: 172.16.0.1 - 172.16.0.254
   - Gateway: 172.16.0.1
   - Broadcast: 172.16.0.255
   - Available IP addresses: 254

2. Monitoring & Security 
   - Subnet: 172.16.1.0/24
   - Range: 172.16.1.1 - 172.16.1.254
   - Gateway: 172.16.1.1
   - Broadcast: 172.16.1.255
   - Available IP addresses: 254

3. Communication 
   - Subnet: 172.16.2.0/24
   - Range: 172.16.2.1 - 172.16.2.254
   - Gateway: 172.16.2.1
   - Broadcast: 172.16.2.255
   - Available IP addresses: 254

4. Productivity & Web Server 
   - Subnet: 172.16.3.0/24
   - Range: 172.16.3.1 - 172.16.3.254
   - Gateway: 172.16.3.1
   - Broadcast: 172.16.3.255
   - Available IP addresses: 254

5. Media Servers
   - Subnet: 172.16.4.0/24
   - Range: 172.16.4.1 - 172.16.4.254
   - Gateway: 172.16.4.1
   - Broadcast: 172.16.4.255
   - Available IP addresses: 254

6. File Share
   - Subnet: 172.16.5.0/24
   - Range: 172.16.5.1 - 172.16.5.254
   - Gateway: 172.16.5.1
   - Broadcast: 172.16.5.255
   - Available IP addresses: 254

7. Home Dashboards 
   - Subnet: 172.16.6.0/24
   - Range: 172.16.6.1 - 172.16.6.254
   - Gateway: 172.16.6.1
   - Broadcast: 172.16.6.255
   - Available IP addresses: 254


# Class C (192.168.0.0) IP plan template

1. Kubernetes & Management
   - Subnet: 192.168.0.0/24
   - Range: 192.168.0.1 - 192.168.0.254
   - Gateway: 192.168.0.1
   - Broadcast: 192.168.0.255
   - Available IP addresses: 254

2. Monitoring & Security 
   - Subnet: 192.168.1.0/24
   - Range: 192.168.1.1 - 192.168.1.254
   - Gateway: 192.168.1.1
   - Broadcast: 192.168.1.255
   - Available IP addresses: 254

3. Communication 
   - Subnet: 192.168.2.0/24
   - Range: 192.168.2.1 - 192.168.2.254
   - Gateway: 192.168.2.1
   - Broadcast: 192.168.2.255
   - Available IP addresses: 254

4. Productivity & Web Server 
   - Subnet: 192.168.3.0/24
   - Range: 192.168.3.1 - 192.168.3.254
   - Gateway: 192.168.3.1
   - Broadcast: 192.168.3.255
   - Available IP addresses: 254

5. Media Servers
   - Subnet: 192.168.4.0/24
   - Range: 192.168.4.1 - 192.168.4.254
   - Gateway: 192.168.4.1
   - Broadcast: 192.168.4.255
   - Available IP addresses: 254

6. File Share
   - Subnet: 192.168.5.0/24
   - Range: 192.168.5.1 - 192.168.5.254
   - Gateway: 192.168.5.1
   - Broadcast: 192.168.5.255
   - Available IP addresses: 254

7. Home Dashboards 
   - Subnet: 192.168.6.0/24
   - Range: 192.168.6.1 - 192.168.6.254
   - Gateway: 192.168.6.1
   - Broadcast: 192.168.6.255
   - Available IP addresses: 254



# Which classes would fit me?

1. Class A Network (10.0.0.0):
    - Range: 10.0.0.0 to 10.255.255.255
    - Total IP addresses: 16,777,216
    - Default subnet mask: 255.0.0.0
    - Supports a large number of hosts (devices) within the network.
    - Typically used for large organizations or networks that require a vast number of IP addresses.


2. Class B Network (172.16.0.0):
    - Range: 172.16.0.0 to 172.31.255.255
    - Total IP addresses: 1,048,576
    - Default subnet mask: 255.255.0.0
    - Provides a moderate number of IP addresses for medium-sized networks.
    - Suitable for medium to large-sized companies or networks with a significant number of devices.


3. Class C Network (192.168.0.0):
    - Range: 192.168.0.0 to 192.168.255.255
    - Total IP addresses: 65,536
    - Default subnet mask: 255.255.255.0
    - Provides a relatively smaller number of IP addresses compared to Class A and Class B networks.
    - Often used for smaller local networks or home networks.