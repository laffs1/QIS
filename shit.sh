#!/bin/bash
# Proxmox NAT bridge setup for isolated VM

# --- Variables ---
BRIDGE="vmbr1"
BRIDGE_IP="10.10.10.1"
BRIDGE_NETMASK="255.255.255.0"
VM_SUBNET="10.10.10.0/24"
LAN_BRIDGE="vmbr0"  # your internet-facing bridge

# --- 1️⃣ Create NAT bridge ---
echo "Creating $BRIDGE..."
cat <<EOF >/etc/network/interfaces.d/$BRIDGE
auto $BRIDGE
iface $BRIDGE inet static
    address $BRIDGE_IP
    netmask $BRIDGE_NETMASK
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF

# Bring bridge up
ip link set $BRIDGE up

# --- 2️⃣ Enable IP forwarding ---
echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# --- 3️⃣ Setup NAT with iptables ---
iptables -t nat -A POSTROUTING -s $VM_SUBNET -o $LAN_BRIDGE -j MASQUERADE
iptables -A FORWARD -s $VM_SUBNET -o $LAN_BRIDGE -j ACCEPT
iptables -A FORWARD -d $VM_SUBNET -m state --state RELATED,ESTABLISHED -i $LAN_BRIDGE -j ACCEPT

# Optional: save iptables rules
if command -v netfilter-persistent &>/dev/null; then
    netfilter-persistent save
else
    apt update && apt install -y iptables-persistent
    netfilter-persistent save
fi

echo "✅ NAT bridge $BRIDGE is ready. Use $BRIDGE_IP as gateway in your VM."
