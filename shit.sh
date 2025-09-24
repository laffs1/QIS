#!/bin/bash

# Exit on any error
set -e

# Variables
BRIDGE_NAME="vmbr2"
PHYSICAL_IFACE="eth1"  # Replace with your physical network interface (e.g., enp0s3)
NETWORK_CONFIG="/etc/network/interfaces"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if the physical interface exists
if ! ip link show "$PHYSICAL_IFACE" > /dev/null 2>&1; then
    echo "Physical interface $PHYSICAL_IFACE does not exist"
    exit 1
fi

# Check if bridge already exists
if ip link show "$BRIDGE_NAME" > /dev/null 2>&1; then
    echo "Bridge $BRIDGE_NAME already exists"
    exit 1
fi

# Create the bridge
ip link add name "$BRIDGE_NAME" type bridge
ip link set "$BRIDGE_NAME" up

# Attach the physical interface to the bridge
ip link set "$PHYSICAL_IFACE" master "$BRIDGE_NAME"
ip link set "$PHYSICAL_IFACE" up

# Optional: Enable DHCP on the bridge (comment out if using static IP)
ip addr flush dev "$PHYSICAL_IFACE"
dhclient "$BRIDGE_NAME"

# Backup existing network configuration
if [ -f "$NETWORK_CONFIG" ]; then
    cp "$NETWORK_CONFIG" "$NETWORK_CONFIG.bak"
    echo "Backed up $NETWORK_CONFIG to $NETWORK_CONFIG.bak"
fi

# Add bridge configuration to /etc/network/interfaces
cat >> "$NETWORK_CONFIG" << EOF

# Bridge setup for $BRIDGE_NAME
auto $BRIDGE_NAME
iface $BRIDGE_NAME inet dhcp
    bridge_ports $PHYSICAL_IFACE
    bridge_stp off
    bridge_fd 0
EOF

# Alternative: Static IP configuration (uncomment and modify if needed)
# cat >> "$NETWORK_CONFIG" << EOF
#
# # Bridge setup for $BRIDGE_NAME
# auto $BRIDGE_NAME
# iface $BRIDGE_NAME inet static
#     address 192.168.1.100
#     netmask 255.255.255.0
#     gateway 192.168.1.1
#     bridge_ports $PHYSICAL_IFACE
#     bridge_stp off
#     bridge_fd 0
# EOF

echo "Bridge $BRIDGE_NAME created and configured successfully"
echo "Physical interface $PHYSICAL_IFACE is attached to $BRIDGE_NAME"

# Restart networking to apply changes (adjust for your system if needed)
if systemctl restart networking > /dev/null 2>&1; then
    echo "Networking service restarted"
else
    echo "Failed to restart networking service. Please restart manually or reboot."
fi
