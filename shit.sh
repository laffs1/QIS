#!/bin/bash

# Script to repair vmbr1 to ensure it gets a valid IP address

# Configuration variables
BRIDGE_NAME="vmbr1"
PHYSICAL_IFACE="${1:-eth1}"  # Default to eth1, override with first argument
CONFIG_FILE="/etc/network/interfaces"
LOG_FILE="/var/log/repair-vmbr1-ip.log"
USE_DHCP="yes"  # Set to "no" for static IP
STATIC_IP="192.168.1.101"  # Different from vmbr0, adjust as needed
STATIC_NETMASK="255.255.255.0"
STATIC_GATEWAY="192.168.1.1"
STATIC_DNS="8.8.8.8"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Exit on any error
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log_message "ERROR: This script must be run as root"
    echo "Please run with sudo or as root"
    exit 1
fi

# Create log file if it doesn't exist
touch "$LOG_FILE" || { echo "Cannot create log file at $LOG_FILE"; exit 1; }
log_message "Starting IP repair for existing bridge $BRIDGE_NAME"

# Check if bridge exists
if ! ip link show "$BRIDGE_NAME" > /dev/null 2>&1; then
    log_message "ERROR: Bridge $BRIDGE_NAME does not exist"
    echo "Bridge $BRIDGE_NAME not found. Use a creation script to set it up."
    exit 1
fi

# Ensure bridge is up
if ! ip link show "$BRIDGE_NAME" | grep -q "state UP"; then
    log_message "Bringing $BRIDGE_NAME up"
    ip link set "$BRIDGE_NAME" up || { log_message "ERROR: Failed to bring $BRIDGE_NAME up"; exit 1; }
else
    log_message "Bridge $BRIDGE_NAME is already up"
fi

# Validate physical interface
if ! ip link show "$PHYSICAL_IFACE" > /dev/null 2>&1; then
    log_message "ERROR: Physical interface $PHYSICAL_IFACE does not exist"
    echo "Available interfaces:"
    ip link show | grep '^[0-9]' | cut -d: -f2 | awk '{print $1}'
    exit 1
fi

# Check if physical interface is attached to bridge
if ! ip link show master "$BRIDGE_NAME" | grep -q "$PHYSICAL_IFACE"; then
    log_message "Attaching $PHYSICAL_IFACE to $BRIDGE_NAME"
    ip link set "$PHYSICAL_IFACE" master "$BRIDGE_NAME" || { log_message "ERROR: Failed to attach $PHYSICAL_IFACE"; exit 1; }
else
    log_message "Physical interface $PHYSICAL_IFACE already attached to $BRIDGE_NAME"
fi

# Ensure physical interface is up
if ! ip link show "$PHYSICAL_IFACE" | grep -q "state UP"; then
    log_message "Bringing $PHYSICAL_IFACE up"
    ip link set "$PHYSICAL_IFACE" up || { log_message "ERROR: Failed to bring $PHYSICAL_IFACE up"; exit 1; }
fi

# Check current IP status
CURRENT_IP=$(ip addr show "$BRIDGE_NAME" | grep -oP 'inet \K[\d.]+')
if [ -n "$CURRENT_IP" ]; then
    log_message "Current IP on $BRIDGE_NAME: $CURRENT_IP"
else
    log_message "No IP assigned to $BRIDGE_NAME"
fi

# Configure IP (DHCP or static)
if [ "$USE_DHCP" = "yes" ]; then
    log_message "Configuring $BRIDGE_NAME with DHCP"
    ip addr flush dev "$PHYSICAL_IFACE" 2>/dev/null || log_message "Warning: Failed to flush IP from $PHYSICAL_IFACE"
    ip addr flush dev "$BRIDGE_NAME" 2>/dev/null || log_message "Warning: Failed to flush IP from $BRIDGE_NAME"
    dhclient -r "$BRIDGE_NAME" 2>/dev/null || true
    if dhclient "$BRIDGE_NAME"; then
        log_message "DHCP lease obtained successfully"
    else
        log_message "ERROR: Failed to obtain DHCP lease"
        echo "Failed to obtain DHCP lease. Check network or DHCP server."
        exit 1
    fi
else
    log_message "Configuring $BRIDGE_NAME with static IP $STATIC_IP"
    ip addr flush dev "$PHYSICAL_IFACE" 2>/dev/null || log_message "Warning: Failed to flush IP from $PHYSICAL_IFACE"
    ip addr flush dev "$BRIDGE_NAME" 2>/dev/null || log_message "Warning: Failed to flush IP from $BRIDGE_NAME"
    ip addr add "$STATIC_IP/$STATIC_NETMASK" dev "$BRIDGE_NAME" || { log_message "ERROR: Failed to set static IP"; exit 1; }
    ip route add default via "$STATIC_GATEWAY" 2>/dev/null || log_message "Warning: Failed to set default gateway"
    echo "nameserver $STATIC_DNS" > /etc/resolv.conf
fi

# Backup existing network configuration
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.$(date +%Y%m%d%H%M%S).bak"
    log_message "Backed up $CONFIG_FILE"
fi

# Remove old bridge configuration to avoid duplicates
log_message "Removing old $BRIDGE_NAME configuration from $CONFIG_FILE"
sed -i "/^auto $BRIDGE_NAME/,/^$/d" "$CONFIG_FILE" 2>/dev/null || log_message "Warning: Failed to remove old $BRIDGE_NAME config"

# Add updated bridge configuration
log_message "Updating $CONFIG_FILE with bridge configuration"
cat >> "$CONFIG_FILE" << EOF

# Bridge setup for $BRIDGE_NAME (repaired $(date))
auto $BRIDGE_NAME
iface $BRIDGE_NAME inet ${USE_DHCP:-yes} dhcp
    bridge_ports $PHYSICAL_IFACE
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
EOF

# Static IP configuration (if enabled)
if [ "$USE_DHCP" != "yes" ]; then
    cat >> "$CONFIG_FILE" << EOF

# Bridge setup for $BRIDGE_NAME (static, repaired $(date))
auto $BRIDGE_NAME
iface $BRIDGE_NAME inet static
    address $STATIC_IP
    netmask $STATIC_NETMASK
    gateway $STATIC_GATEWAY
    dns-nameservers $STATIC_DNS
    bridge_ports $PHYSICAL_IFACE
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
EOF
fi

# Restart networking
log_message "Restarting networking service"
if systemctl restart networking > /dev/null 2>&1; then
    log_message "Networking service restarted successfully"
elif service networking restart > /dev/null 2>&1; then
    log_message "Networking service restarted successfully (using service)"
else
    log_message "Warning: Could not restart networking service. Manual restart or reboot required."
    echo "Please restart networking manually or reboot the system."
fi

# Verify IP assignment
NEW_IP=$(ip addr show "$BRIDGE_NAME" | grep -oP 'inet \K[\d.]+')
if [ -n "$NEW_IP" ]; then
    log_message "Bridge $BRIDGE_NAME now has IP: $NEW_IP"
    echo "Success: Bridge $BRIDGE_NAME repaired and assigned IP $NEW_IP"
else
    log_message "ERROR: Bridge $BRIDGE_NAME still has no IP"
    echo "Failed to assign IP to $BRIDGE_NAME. Check $LOG_FILE for details."
    exit 1
fi

# Proxmox-specific note
if [ -d "/etc/pve" ]; then
    log_message "Detected Proxmox environment. Ensure VM network settings use $BRIDGE_NAME"
    echo "Proxmox detected. Verify your VM is using bridge $BRIDGE_NAME in network settings."
fi

log_message "Repair completed successfully"
echo "Repair complete. Logs available at $LOG_FILE"
