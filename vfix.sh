#!/bin/bash
set -e

echo "======================================="
echo "   Home Assistant venv Fix Script"
echo "======================================="

echo ">>> Fixing venv in /srv/homeassistant..."

# Ensure the homeassistant user exists
id -u homeassistant &>/dev/null || useradd -rm homeassistant

# Run venv fix as homeassistant
sudo -u homeassistant -H bash <<'EOF'
cd /srv/homeassistant || exit 0
rm -rf bin include lib lib64 pyvenv.cfg
python3 -m venv --without-pip .
curl -sS https://bootstrap.pypa.io/get-pip.py | ./bin/python
source bin/activate
pip install --upgrade pip wheel setuptools homeassistant
EOF

# Restart service if it exists
systemctl restart home-assistant.service || true

echo ">>> venv fixed. Home Assistant restarted (if service exists)."
