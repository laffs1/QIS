#!/bin/bash
# Rocket.Chat Automated Installation Script for Ubuntu (Cloudflare Tunnel)
# Run as root or with sudo

set -e

# Variables
ROCKETCHAT_VERSION="6.13.0"      # Change if needed
INSTALL_DIR="/opt/Rocket.Chat"
NODE_USER="rocketchat"
MONGO_REPLSET="rs01"
ROOT_URL="http://localhost:3000"
PORT="3000"

echo "=== Updating Ubuntu packages ==="
apt update && apt upgrade -y

echo "=== Installing prerequisites ==="
apt install -y curl build-essential graphicsmagick npm gnupg lsb-release software-properties-common

echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "=== Installing Deno ==="
curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh
export DENO_INSTALL=/usr/local
export PATH="$DENO_INSTALL/bin:$PATH"

echo "=== Installing MongoDB ==="
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt update
apt install -y mongodb-org
systemctl enable --now mongod

echo "=== Configuring MongoDB replica set ==="
sed -i "/^replication:/,/^$/d" /etc/mongod.conf
cat << EOF >> /etc/mongod.conf

replication:
  replSetName: $MONGO_REPLSET
EOF

systemctl restart mongod
mongosh --eval "rs.initiate()"

echo "=== Installing Rocket.Chat ==="
curl -L https://releases.rocket.chat/$ROCKETCHAT_VERSION/download -o /tmp/rocket.chat.tgz
tar -xzf /tmp/rocket.chat.tgz -C /tmp
cd /tmp/bundle/programs/server
npm install --production
sudo mv /tmp/bundle $INSTALL_DIR

echo "=== Creating rocketchat user ==="
sudo useradd -M $NODE_USER && sudo usermod -L $NODE_USER
sudo chown -R $NODE_USER:$NODE_USER $INSTALL_DIR

NODE_PATH=$(which node)

echo "=== Creating systemd service ==="
cat << EOF | sudo tee /lib/systemd/system/rocketchat.service
[Unit]
Description=The Rocket.Chat server
After=network.target remote-fs.target nss-lookup.target mongod.service

[Service]
ExecStart=$NODE_PATH $INSTALL_DIR/main.js
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rocketchat
User=$NODE_USER
Environment=ROOT_URL=$ROOT_URL
Environment=PORT=$PORT
Environment=MONGO_URL=mongodb://localhost:27017/rocketchat?replicaSet=$MONGO_REPLSET
Environment=MONGO_OPLOG_URL=mongodb://localhost:27017/local?replicaSet=$MONGO_REPLSET

[Install]
WantedBy=multi-user.target
EOF

echo "=== Enabling and starting Rocket.Chat service ==="
systemctl daemon-reload
systemctl enable --now rocketchat
systemctl status rocketchat

echo "=== Rocket.Chat installation complete ==="
echo "Use Cloudflare Tunnel to expose http://localhost:$PORT externally."
