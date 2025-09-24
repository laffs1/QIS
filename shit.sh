#!/bin/bash
# Enable firewall for VM 103
qm set 103 --firewall 1

# Block VM from accessing LAN
qm firewall add 103 --direction OUT --action DROP --dest 192.168.4.0/22 --comment "Block LAN"
qm firewall add 103 --direction IN --action DROP --source 192.168.4.0/22 --comment "Block LAN"

echo "✅ VM 103 firewall configured. It cannot see the LAN but can access the internet."
