#!/bin/bash
# Simple OctoPrint Installer for Ubuntu Server

set -e

# User & directories
OCTOPRINT_USER="ubuntu"
OCTOPRINT_DIR="/home/$OCTOPRINT_USER/OctoPrint"
VENV_DIR="$OCTOPRINT_DIR/venv"

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt install -y python3 python3-pip python3-dev python3-venv git libyaml-dev build-essential libffi-dev libssl-dev

# Add user to serial groups for printer access
sudo usermod -aG dialout,tty $OCTOPRINT_USER

# Setup OctoPrint directory and virtual environment
mkdir -p $OCTOPRINT_DIR
cd $OCTOPRINT_DIR
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Install OctoPrint
pip install --upgrade pip wheel
pip install --no-cache-dir octoprint

# Create systemd service for OctoPrint
sudo tee /etc/systemd/system/octoprint.service > /dev/null <<EOL
[Unit]
Description=OctoPrint 3D Printer Server
After=network-online.target
Wants=network-online.target

[Service]
Environment="LC_ALL=C.UTF-8"
Environment="LANG=C.UTF-8"
Type=simple
User=$OCTOPRINT_USER
ExecStart=$VENV_DIR/bin/octoprint serve

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable/start service
sudo systemctl daemon-reload
sudo systemctl enable octoprint.service
sudo systemctl start octoprint.service

echo "✅ OctoPrint installed and running!"
echo "Access it at http://<server_ip>:5000"
echo "Control the service with: sudo systemctl {start|stop|restart} octoprint"
