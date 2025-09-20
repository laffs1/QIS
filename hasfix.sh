#!/bin/bash
set -e

echo "======================================="
echo "   Home Assistant Service Setup Script"
echo "======================================="

# Ensure the homeassistant user exists
id -u homeassistant &>/dev/null || useradd -rm homeassistant

# Create systemd service
echo ">>> Creating systemd service..."
cat >/etc/systemd/system/home-assistant.service <<EOL
[Unit]
Description=Home Assistant
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=homeassistant
ExecStart=/srv/homeassistant/bin/hass -c "/srv/homeassistant"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

# Enable and start service
echo ">>> Enabling and starting Home Assistant service..."
systemctl daemon-reexec
systemctl enable home-assistant.service
systemctl start home-assistant.service

echo ">>> Done!"
echo "Home Assistant service is running."
