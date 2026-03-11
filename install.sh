#!/usr/bin/env bash
set -euo pipefail

REPO="foxly-it/adguard-home-updater"
BASE_URL="https://raw.githubusercontent.com/${REPO}/main"

SCRIPT_URL="${BASE_URL}/adguard-update"

INSTALL_PATH="/usr/local/sbin/adguard-update"

SERVICE_FILE="/etc/systemd/system/adguard-update.service"
TIMER_FILE="/etc/systemd/system/adguard-update.timer"

echo
echo "AdGuard Home Bare-Metal Updater Installer"
echo

# ---------------------------------------------------------
# root check
# ---------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# ---------------------------------------------------------
# install updater script
# ---------------------------------------------------------

echo "Downloading updater..."

curl --fail --location --silent --show-error \
  -o "$INSTALL_PATH" \
  "$SCRIPT_URL"

chmod +x "$INSTALL_PATH"

echo "Updater installed to:"
echo "  $INSTALL_PATH"
echo

# ---------------------------------------------------------
# install systemd service
# ---------------------------------------------------------

echo "Installing systemd service..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AdGuard Home Update Check

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/adguard-update
User=root
EOF

# ---------------------------------------------------------
# install systemd timer
# ---------------------------------------------------------

echo "Installing systemd timer..."

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Daily AdGuard Home Update Check

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h
AccuracySec=10m

[Install]
WantedBy=timers.target
EOF

# ---------------------------------------------------------
# reload systemd
# ---------------------------------------------------------

systemctl daemon-reload

echo
echo "Systemd service and timer installed."
echo

# ---------------------------------------------------------
# ask user to enable timer
# ---------------------------------------------------------

read -r -p "Enable automatic updates via systemd timer? (y/N): " ENABLE_TIMER

if [[ "$ENABLE_TIMER" =~ ^[Yy]$ ]]; then

  systemctl enable --now adguard-update.timer

  echo
  echo "Automatic updates enabled."
  echo

else

  echo
  echo "Automatic updates not enabled."
  echo "You can enable them later with:"
  echo
  echo "  sudo systemctl enable --now adguard-update.timer"
  echo

fi

# ---------------------------------------------------------
# done
# ---------------------------------------------------------

echo "Installation completed."
echo

echo "Test the updater with:"
echo
echo "  sudo adguard-update --dry-run"
echo