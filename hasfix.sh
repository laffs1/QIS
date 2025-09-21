#!/bin/bash
set -e

echo "======================================="
echo "   Home Assistant Full Install Script"
echo "======================================="

# 1️⃣ Update system
echo ">>> Updating system..."
apt-get update -y && apt-get upgrade -y

# 2️⃣ Install dependencies
echo ">>> Installing dependencies..."
apt-get install -y \
    python3-full python3-venv python3-pip \
    libffi-dev libssl-dev libjpeg-dev zlib1g-dev \
    autoconf build-essential bluez libopenjp2-7 \
    libtiff6 libturbojpeg0-dev tzdata \
    avahi-daemon dbus cron git curl

# 3️⃣ Create Home Assistant user
echo ">>> Creating homeassistant user..."
id -u homeassistant &>/dev/null || useradd -rm homeassistant

# 4️⃣ Setup venv
echo ">>> Creating Home Assistant venv..."
mkdir -p /srv/homeassistant
chown homeassistant:homeassistant /srv/homeassistant

sudo -u homeassistant -H bash <<'EOF'
cd /srv/homeassistant
rm -rf bin include lib lib64 pyvenv.cfg
python3 -m venv --without-pip .
curl -sS https://bootstrap.pypa.io/get-pip.py | ./bin/python
source bin/activate
pip install --upgrade pip wheel setuptools homeassistant
EOF

# 5️⃣ Create minimal configuration
echo ">>> Creating minimal configuration..."
mkdir -p /srv/homeassistant
cat >/srv/homeassistant/configuration.yaml <<EOL
homeassistant:
  name: Home
  latitude: 0
  longitude: 0
  elevation: 0
  unit_system: metric
  currency: USD
  time_zone: UTC
EOL

chown -R homeassistant:homeassistant /srv/homeassistant

# 6️⃣ Create systemd service
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
Environment="PATH=/srv/homeassistant/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOL

# 7️⃣ Enable and start service
echo ">>> Enabling and starting Home Assistant service..."
systemctl daemon-reexec
systemctl enable home-assistant.service
systemctl restart home-assistant.service

# 8️⃣ Setup weekly auto-update
echo ">>> Setting up weekly auto-update..."
cat >/etc/cron.weekly/home-assistant-update <<'EOL'
#!/bin/bash
su - homeassistant -c "
source /srv/homeassistant/bin/activate
pip install --upgrade pip wheel setuptools homeassistant
"
systemctl restart home-assistant.service
EOL

chmod +x /etc/cron.weekly/home-assistant-update

echo ">>> Done!"
echo "Home Assistant is running at http://<your-lxc-ip>:8123"
echo "It will auto-update weekly."
