#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# AdGuard Home Updater Installer
#
# Installs the updater script and optional systemd timer
# for automatic update checks.
#
# Project
# https://github.com/foxly-it/adguard-home-updater
# =========================================================

REPO="foxly-it/adguard-home-updater"

INSTALL_PATH="/usr/local/sbin/adguard-update"

SERVICE_FILE="/etc/systemd/system/adguard-update.service"
TIMER_FILE="/etc/systemd/system/adguard-update.timer"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# ---------------------------------------------------------
# root check
# ---------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
echo "Please run as root"
exit 1
fi

echo
echo "AdGuard Home Updater Installer"
echo

# ---------------------------------------------------------
# detect latest release
# ---------------------------------------------------------

echo "Detecting latest release..."

LATEST_VERSION=$(curl --fail --silent --show-error \
"$API_URL" \
| grep '"tag_name"' \
| head -n1 \
| cut -d '"' -f4)

if [[ -z "$LATEST_VERSION" ]]; then
echo "Failed to detect latest release"
exit 1
fi

echo "Latest version: $LATEST_VERSION"
echo

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_VERSION}/adguard-update"

# ---------------------------------------------------------
# download updater
# ---------------------------------------------------------

echo "Downloading updater..."

curl --fail --location --silent --show-error \
-o "$INSTALL_PATH" \
"$DOWNLOAD_URL"

chmod +x "$INSTALL_PATH"

echo
echo "Updater installed:"
echo "  $INSTALL_PATH"
echo

# ---------------------------------------------------------
# install systemd service
# ---------------------------------------------------------

echo "Installing systemd service..."

cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=AdGuard Home Update Check
Documentation=https://github.com/foxly-it/adguard-home-updater
ConditionPathExists=/opt/AdGuardHome/AdGuardHome

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/adguard-update
User=root
EOF

# ---------------------------------------------------------
# install systemd timer
# ---------------------------------------------------------

echo "Installing systemd timer..."

cat > "$TIMER_FILE" <<'EOF'
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
echo "Enable later with:"
echo
echo "sudo systemctl enable --now adguard-update.timer"
echo

fi

# ---------------------------------------------------------
# show installed version
# ---------------------------------------------------------

echo "Installed updater version:"
echo

/usr/local/sbin/adguard-update --version

echo
echo "Installation completed."
echo

echo "Test with:"
echo
echo "sudo adguard-update --dry-run"
echo