#!/usr/bin/env bash
set -euo pipefail 2> /dev/null || set -eu

# =========================================================
# AdGuard Home Updater Installer
# =========================================================

INSTALLER_VERSION="1.1.1"

REPO="foxly-it/adguard-home-updater"

INSTALL_PATH="/usr/local/sbin/adguard-update"

SERVICE_FILE="/etc/systemd/system/adguard-update.service"
TIMER_FILE="/etc/systemd/system/adguard-update.timer"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"

ACTION="install"
INTERACTIVE=true

# ---------------------------------------------------------
# detect piped execution (no TTY)
# ---------------------------------------------------------

if [[ ! -t 0 ]]; then
    INTERACTIVE=false
fi

# ---------------------------------------------------------
# parse arguments
# ---------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        uninstall)
            ACTION="uninstall"
            ;;
        --no-interactive)
            INTERACTIVE=false
            ;;
        help | -h | --help)
            ACTION="help"
            ;;
    esac
done

# ---------------------------------------------------------
# banner
# ---------------------------------------------------------

banner() {
    echo
    echo "=============================================="
    echo "      AdGuard Home Updater Installer"
    echo "=============================================="
    echo "Installer version: $INSTALLER_VERSION"
    echo
}

# ---------------------------------------------------------
# usage
# ---------------------------------------------------------

usage() {
    echo
    echo "Usage:"
    echo
    echo "  install.sh install            Install updater"
    echo "  install.sh uninstall          Remove updater"
    echo
    echo "Options:"
    echo
    echo "  --no-interactive              Disable prompts"
    echo
}

# ---------------------------------------------------------
# root check
# ---------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root"
    exit 1
fi

banner

# ---------------------------------------------------------
# architecture detection
# ---------------------------------------------------------

ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH_NAME="amd64" ;;
    aarch64 | arm64) ARCH_NAME="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "✔ detected architecture: $ARCH ($ARCH_NAME)"

# ---------------------------------------------------------
# installer version check
# ---------------------------------------------------------

REMOTE_INSTALLER_VERSION=$(curl -fsSL \
    https://raw.githubusercontent.com/${REPO}/main/install.sh |
    grep INSTALLER_VERSION |
    head -n1 |
    cut -d '"' -f2 || echo "unknown")

if [[ "$REMOTE_INSTALLER_VERSION" != "$INSTALLER_VERSION" ]] && [[ "$REMOTE_INSTALLER_VERSION" != "unknown" ]]; then
    echo
    echo "⚠ A newer installer version is available"
    echo "  Current: $INSTALLER_VERSION"
    echo "  Latest : $REMOTE_INSTALLER_VERSION"
    echo
fi

# ---------------------------------------------------------
# help
# ---------------------------------------------------------

if [[ "$ACTION" == "help" ]]; then
    usage
    exit 0
fi

# ---------------------------------------------------------
# uninstall
# ---------------------------------------------------------

if [[ "$ACTION" == "uninstall" ]]; then

    echo
    echo "Removing updater..."

    systemctl stop adguard-update.timer 2> /dev/null || true
    systemctl disable adguard-update.timer 2> /dev/null || true

    rm -f "$SERVICE_FILE"
    rm -f "$TIMER_FILE"

    systemctl daemon-reload

    rm -f "$INSTALL_PATH"

    echo "✔ updater removed"
    echo

    exit 0
fi

# ---------------------------------------------------------
# detect latest release
# ---------------------------------------------------------

echo
echo "Detecting latest release..."

LATEST_VERSION=$(curl -fsSL "$API_URL" |
    grep '"tag_name"' |
    head -n1 |
    cut -d '"' -f4)

if [[ -z "$LATEST_VERSION" ]]; then
    echo "Failed to detect latest release"
    exit 1
fi

echo "✔ latest version: $LATEST_VERSION"

# ---------------------------------------------------------
# existing installation
# ---------------------------------------------------------

if [[ -f "$INSTALL_PATH" ]]; then

    CURRENT_VERSION=$("$INSTALL_PATH" --version 2> /dev/null | awk '{print $NF}' || echo "unknown")

    # normalize versions (fixes v-prefix issue)
    CURRENT_VERSION="${CURRENT_VERSION#v}"
    LATEST_CLEAN="${LATEST_VERSION#v}"

    echo "✔ existing installation detected"
    echo "  installed: $CURRENT_VERSION"
    echo "  latest   : $LATEST_VERSION"

    if [[ "$CURRENT_VERSION" == "$LATEST_CLEAN" ]]; then
        echo
        echo "Updater already up to date."
        exit 0
    fi

    echo "Updating updater..."
fi

# ---------------------------------------------------------
# download + verify
# ---------------------------------------------------------

TMP_DIR=$(mktemp -d)

echo
echo "Downloading updater..."

BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_VERSION}"

curl -fsSL --retry 3 \
    -o "$TMP_DIR/adguard-update" \
    "$BASE_URL/adguard-update"

curl -fsSL --retry 3 \
    -o "$TMP_DIR/checksums.txt" \
    "$BASE_URL/checksums.txt"

echo "Verifying checksum..."

EXPECTED=$(grep "adguard-update" "$TMP_DIR/checksums.txt" | awk '{print $1}')
DOWNLOADED=$(sha256sum "$TMP_DIR/adguard-update" | awk '{print $1}')

if [[ "$EXPECTED" != "$DOWNLOADED" ]]; then
    echo "Checksum verification failed"
    exit 1
fi

echo "✔ checksum verified"

mv "$TMP_DIR/adguard-update" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

rm -rf "$TMP_DIR"

echo "✔ updater installed"

# ---------------------------------------------------------
# install systemd service
# ---------------------------------------------------------

if [[ ! -f "$SERVICE_FILE" ]]; then

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AdGuard Home Update Check
Documentation=https://github.com/${REPO}
ConditionPathExists=/opt/AdGuardHome/AdGuardHome

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH
User=root
EOF

    echo "✔ systemd service installed"
fi

# ---------------------------------------------------------
# install systemd timer
# ---------------------------------------------------------

if [[ ! -f "$TIMER_FILE" ]]; then

    cat > "$TIMER_FILE" << EOF
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

    echo "✔ systemd timer installed"
fi

systemctl daemon-reload

# ---------------------------------------------------------
# enable timer
# ---------------------------------------------------------

ENABLE_TIMER="n"

if [[ "$INTERACTIVE" == true ]]; then
    read -r -p "Enable automatic updates? (y/N): " ENABLE_TIMER
else
    ENABLE_TIMER="y"
fi

if [[ "$ENABLE_TIMER" =~ ^[Yy]$ ]]; then

    systemctl enable --now adguard-update.timer

    echo "✔ automatic updates enabled"

else

    echo
    echo "Automatic updates disabled"
    echo
    echo "Enable later with:"
    echo
    echo "sudo systemctl enable --now adguard-update.timer"

fi

echo
echo "Installation completed"
echo
echo "Test with:"
echo
echo "sudo adguard-update --dry-run"
echo
