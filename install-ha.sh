#!/bin/bash
set -e

echo "======================================="
echo "   Home Assistant LXC Setup Script"
echo "======================================="
echo "Choose an option:"
echo "1) Full Install (Home Assistant Core)"
echo "2) Fix venv only"
read -p "Enter choice [1-2]: " choice

if [ "$choice" == "1" ]; then
    echo ">>> Updating system..."
    apt-get update -y && apt-get upgrade -y

    echo ">>> Installing dependencies..."
    apt-get install -y \
        python3-full \
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
        cron \
        git \
        curl

    echo ">>> Creating Home Assistant user..."
    id -u homeassistant &>/dev/null || useradd -rm homeassistant

    echo ">>> Creating venv..."
    mkdir -p /srv/homeassistant
    chown homeassistant:homeassistant /srv/homeassistant

    sudo -u homeassistant -H bash <<'EOF'
cd /srv/homeassistant
python3 -m venv --without-pip .
curl -sS https://bootstrap.pypa.io/get-pip.py | ./bin/python
source bin/activate
pip install --upgrade pip wheel setuptools
pip install homeassistant
EOF

    echo ">>> Creating systemd service..."
    cat >/etc/systemd/system/home-assistant.service <<'EOL'
[Unit]
Description=Home Assistant
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=homeassistant
ExecStart=/srv/homeassistant/bin/hass -c "/home/homeassistant/.homeassistant"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    echo ">>> Enabling and starting Home Assistant service..."
    systemctl daemon-reexec
    systemctl enable home-assistant
    systemctl start home-assistant

    echo ">>> Setting up weekly auto-update..."
    cat >/etc/cron.weekly/home-assistant-update <<'EOL'
#!/bin/bash
sudo -u homeassistant -H bash <<EOF
source /srv/homeassistant/bin/activate
pip install --upgrade pip wheel setuptools homeassistant
EOF
systemctl restart home-assistant
EOL

    chmod +x /etc/cron.weekly/home-assistant-update

    echo ">>> Done!"
    echo "Home Assistant Core is running at http://<your-lxc-ip>:8123"
    echo "It will auto-update weekly."

elif [ "$choice" == "2" ]; then
    echo ">>> Fixing venv in /srv/homeassistant..."
    sudo -u homeassistant -H bash <<'EOF'
cd /srv/homeassistant
rm -rf bin include lib lib64 pyvenv.cfg
python3 -m venv --without-pip .
curl -sS https://bootstrap.pypa.io/get-pip.py | ./bin/python
source bin/activate
pip install --upgrade pip wheel setuptools homeassistant
EOF
    systemctl restart home-assistant || true
    echo ">>> venv fixed. Home Assistant restarted (if service exists)."

else
    echo "Invalid choice. Exiting."
    exit 1
fi
