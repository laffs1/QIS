#!/bin/bash
set -e

echo ">>> Updating system..."
apt-get update -y && apt-get upgrade -y

echo ">>> Installing dependencies..."
apt-get install -y \
    python3 \
    python3-venv \
    python3-pip \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    autoconf \
    build-essential \
    bluez \
    libopenjp2-7 \
    libtiff6 \
    libturbojpeg0-dev \
    tzdata \
    avahi-daemon \
    dbus \
    git \
    curl

echo ">>> Creating Home Assistant user..."
id -u homeassistant &>/dev/null || useradd -rm homeassistant

echo ">>> Creating venv..."
mkdir -p /srv/homeassistant
chown homeassistant:homeassistant /srv/homeassistant

sudo -u homeassistant -H bash <<EOF
cd /srv/homeassistant
python3 -m venv .
source bin/activate
pip install --upgrade pip wheel setuptools
pip install homeassistant
EOF

echo ">>> Creating systemd service with auto-update..."
cat >/etc/systemd/system/home-assistant.service <<'EOL'
[Unit]
Description=Home Assistant
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=homeassistant
WorkingDirectory=/srv/homeassistant
ExecStartPre=/bin/bash -c 'source /srv/homeassistant/bin/activate && pip install --upgrade pip wheel setuptools homeassistant'
ExecStart=/srv/homeassistant/bin/hass -c "/home/homeassistant/.homeassistant"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

echo ">>> Enabling and starting Home Assistant service..."
systemctl daemon-reexec
systemctl enable home-assistant
systemctl start home-assistant

echo ">>> Done! Home Assistant Core will now auto-update at every boot and is running at http://<your-lxc-ip>:8123"
