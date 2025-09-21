#!/bin/bash
set -e

echo "======================================="
echo "   Home Assistant Docker Install Script"
echo "======================================="

# 1️⃣ Update system
echo ">>> Updating system..."
apt-get update -y && apt-get upgrade -y

# 2️⃣ Install Docker dependencies
echo ">>> Installing Docker dependencies..."
apt-get install -y \
    curl \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# 3️⃣ Add Docker repository
echo ">>> Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

# 4️⃣ Install Docker
echo ">>> Installing Docker..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 5️⃣ Configure overlay2 storage driver
echo ">>> Configuring Docker storage driver..."
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOL
{
  "storage-driver": "overlay2"
}
EOL
systemctl restart docker

# 6️⃣ Remove broken Home Assistant container/images
echo ">>> Cleaning up broken Home Assistant containers/images..."
docker rm -f homeassistant 2>/dev/null || true
docker rmi ghcr.io/home-assistant/home-assistant:stable 2>/dev/null || true
docker system prune -af

# 7️⃣ Create config folder
echo ">>> Creating HA config folder..."
mkdir -p /srv/homeassistant
chown root:root /srv/homeassistant

# 8️⃣ Pull fresh Home Assistant Docker image
echo ">>> Pulling Home Assistant Docker image..."
docker pull ghcr.io/home-assistant/home-assistant:stable

# 9️⃣ Create systemd service
echo ">>> Creating systemd service..."
cat >/etc/systemd/system/home-assistant-docker.service <<EOL
[Unit]
Description=Home Assistant Docker Container
After=network.target docker.service
Requires=docker.service

[Service]
Restart=unless-stopped
User=root
ExecStart=/usr/bin/docker run --rm \
  --name homeassistant \
  -v /srv/homeassistant:/config \
  -e TZ=UTC \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable
ExecStop=/usr/bin/docker stop homeassistant

[Install]
WantedBy=multi-user.target
EOL

# 10️⃣ Enable and start the service
echo ">>> Enabling and starting Home Assistant Docker service..."
systemctl daemon-reexec
systemctl enable home-assistant-docker.service
systemctl start home-assistant-docker.service

echo ">>> Done!"
echo "Home Assistant is running in Docker at http://<your-lxc-ip>:8123"
echo "It will automatically start at boot."
