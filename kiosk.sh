#!/bin/bash
# Setup Chromium Kiosk on Pi OS Lite (Surface RT)

echo "[*] Disabling desktop environment..."
sudo systemctl disable lightdm gdm3 xdm 2>/dev/null || true
sudo systemctl set-default multi-user.target

echo "[*] Installing minimal X + Chromium..."
sudo apt update
sudo apt install -y --no-install-recommends \
  xserver-xorg x11-xserver-utils xinit openbox unclutter chromium-browser

echo "[*] Writing kiosk config (~/.xinitrc)..."
cat > ~/.xinitrc <<'EOF'
xset s off
xset -dpms
xset s noblank
unclutter -idle 0 &
chromium-browser --noerrdialogs --disable-infobars --kiosk http://192.168.6.243:8123
EOF
chmod +x ~/.xinitrc

echo "[*] Setting up autologin + kiosk start..."
# enable console autologin for user 'pi' (change if your user is different)
sudo raspi-config nonint do_boot_behaviour B2

if ! grep -q startx ~/.bash_profile 2>/dev/null; then
  echo '[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx' >> ~/.bash_profile
fi

echo "[*] Done! Reboot and it will auto-login + start Chromium in kiosk mode."
echo "To exit kiosk: press CTRL+ALT+BACKSPACE."
