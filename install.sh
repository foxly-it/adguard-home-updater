#!/usr/bin/env bash
set -Eeuo pipefail

INSTALLER_VERSION="2.0.0"
SETTINGS_VERSION="3"
REPO="${UPDATER_REPO:-foxly-it/adguard-home-updater}"
INSTALL_PATH="${UPDATER_INSTALL_PATH:-/usr/local/sbin/adguard-update}"
SERVICE_FILE="${UPDATER_SERVICE_FILE:-/etc/systemd/system/adguard-update.service}"
TIMER_FILE="${UPDATER_TIMER_FILE:-/etc/systemd/system/adguard-update.timer}"
SETTINGS_FILE="${UPDATER_SETTINGS_FILE:-/etc/default/adguard-update}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"

ACTION=install
INTERACTIVE=true
TIMER_MODE=""
SCHEDULE=""
RUN_TIME=""
WEEKDAY=""
RANDOM_DELAY=""
HEALTH_DOMAIN=""
UPDATE_MODE=""
RELEASE_DELAY_DAYS=""
BACKUP_RETENTION=""
HEALTH_RETRIES=""
HEALTH_TIMEOUT=""
HEALTH_FAILURE=""
TIMER_EXPLICIT=false
TMP_DIR=""
MIGRATION_NEEDED=false

cleanup() { [[ -z "$TMP_DIR" || ! -d "$TMP_DIR" ]] || rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT
fail() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: install.sh [install|uninstall] [OPTIONS]

Options:
  --timer enabled|disabled  Enable or disable scheduled updates
  --schedule daily|weekly   Select the timer frequency
  --time HH:MM              Set the local execution time
  --weekday Mon..Sun        Set the weekday for weekly execution
  --random-delay DURATION   Add a systemd randomized delay (for example 0 or 1h)
  --health-domain DOMAIN    DNS name used by the post-update health check
  --update-mode MODE        automatic or notify
  --release-delay DAYS      Wait 0 to 30 days before automatic installation
  --backup-retention COUNT  Keep 1 to 10 versioned backups
  --health-retries COUNT    Retry the DNS check 1 to 60 times
  --health-timeout SECONDS  Use a per-query timeout from 1 to 30 seconds
  --health-failure ACTION   rollback or warn
  --enable-timer            Compatibility alias for --timer enabled
  --disable-timer           Compatibility alias for --timer disabled
  --no-interactive          Never prompt; use supplied or stored settings
  -h, --help                Show this help
EOF
}

require_commands() {
    local cmd missing=()
    for cmd in "$@"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
    ((${#missing[@]} == 0)) || {
        fail "Missing required commands: ${missing[*]}"
        return 1
    }
}

extract_tag() { sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1; }
checksum_for() { awk -v name="$2" '$2 == name || $2 == "./" name {print $1; exit}' "$1"; }

stored_setting() {
    local key=$1
    [[ -f "$SETTINGS_FILE" ]] || return 0
    awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$SETTINGS_FILE"
}

validate_settings() {
    [[ "$TIMER_MODE" == enabled || "$TIMER_MODE" == disabled ]] ||
        {
            fail "--timer must be enabled or disabled"
            return 1
        }
    [[ "$SCHEDULE" == daily || "$SCHEDULE" == weekly ]] ||
        {
            fail "--schedule must be daily or weekly"
            return 1
        }
    [[ "$RUN_TIME" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] ||
        {
            fail "--time must use the 24-hour HH:MM format"
            return 1
        }
    [[ "$WEEKDAY" =~ ^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$ ]] ||
        {
            fail "--weekday must be Mon, Tue, Wed, Thu, Fri, Sat, or Sun"
            return 1
        }
    [[ "$RANDOM_DELAY" =~ ^(0|[0-9]+(s|m|h|d))$ ]] ||
        {
            fail "--random-delay must be 0 or a duration such as 30m or 1h"
            return 1
        }
    [[ "$HEALTH_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] ||
        {
            fail "--health-domain is not a valid DNS name"
            return 1
        }
    [[ "$UPDATE_MODE" == automatic || "$UPDATE_MODE" == notify ]] || {
        fail "--update-mode must be automatic or notify"
        return 1
    }
    [[ "$RELEASE_DELAY_DAYS" =~ ^([0-9]|[12][0-9]|30)$ ]] || {
        fail "--release-delay must be between 0 and 30 days"
        return 1
    }
    [[ "$BACKUP_RETENTION" =~ ^([1-9]|10)$ ]] || {
        fail "--backup-retention must be between 1 and 10"
        return 1
    }
    [[ "$HEALTH_RETRIES" =~ ^([1-9]|[1-5][0-9]|60)$ ]] || {
        fail "--health-retries must be between 1 and 60"
        return 1
    }
    [[ "$HEALTH_TIMEOUT" =~ ^([1-9]|[12][0-9]|30)$ ]] || {
        fail "--health-timeout must be between 1 and 30 seconds"
        return 1
    }
    [[ "$HEALTH_FAILURE" == rollback || "$HEALTH_FAILURE" == warn ]] || {
        fail "--health-failure must be rollback or warn"
        return 1
    }
}

while (($# > 0)); do
    case "$1" in
        install | uninstall) ACTION=$1 ;;
        --timer)
            [[ $# -ge 2 ]] || {
                fail "--timer requires a value"
                exit 2
            }
            TIMER_MODE=$2
            TIMER_EXPLICIT=true
            shift
            ;;
        --schedule)
            [[ $# -ge 2 ]] || {
                fail "--schedule requires a value"
                exit 2
            }
            SCHEDULE=$2
            shift
            ;;
        --time)
            [[ $# -ge 2 ]] || {
                fail "--time requires a value"
                exit 2
            }
            RUN_TIME=$2
            shift
            ;;
        --weekday)
            [[ $# -ge 2 ]] || {
                fail "--weekday requires a value"
                exit 2
            }
            WEEKDAY=$2
            shift
            ;;
        --random-delay)
            [[ $# -ge 2 ]] || {
                fail "--random-delay requires a value"
                exit 2
            }
            RANDOM_DELAY=$2
            shift
            ;;
        --health-domain)
            [[ $# -ge 2 ]] || {
                fail "--health-domain requires a value"
                exit 2
            }
            HEALTH_DOMAIN=$2
            shift
            ;;
        --update-mode)
            [[ $# -ge 2 ]] || {
                fail "--update-mode requires a value"
                exit 2
            }
            UPDATE_MODE=$2
            shift
            ;;
        --release-delay)
            [[ $# -ge 2 ]] || {
                fail "--release-delay requires a value"
                exit 2
            }
            RELEASE_DELAY_DAYS=$2
            shift
            ;;
        --backup-retention)
            [[ $# -ge 2 ]] || {
                fail "--backup-retention requires a value"
                exit 2
            }
            BACKUP_RETENTION=$2
            shift
            ;;
        --health-retries)
            [[ $# -ge 2 ]] || {
                fail "--health-retries requires a value"
                exit 2
            }
            HEALTH_RETRIES=$2
            shift
            ;;
        --health-timeout)
            [[ $# -ge 2 ]] || {
                fail "--health-timeout requires a value"
                exit 2
            }
            HEALTH_TIMEOUT=$2
            shift
            ;;
        --health-failure)
            [[ $# -ge 2 ]] || {
                fail "--health-failure requires a value"
                exit 2
            }
            HEALTH_FAILURE=$2
            shift
            ;;
        --enable-timer)
            TIMER_MODE=enabled
            TIMER_EXPLICIT=true
            ;;
        --disable-timer)
            TIMER_MODE=disabled
            TIMER_EXPLICIT=true
            ;;
        --no-interactive) INTERACTIVE=false ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
    shift
done

[[ -t 0 ]] || INTERACTIVE=false
((EUID == 0)) || {
    fail "Please run the installer as root"
    exit 1
}
require_commands curl tar sha256sum flock systemctl dig grep awk sed install mktemp mv

if [[ "$ACTION" == uninstall ]]; then
    systemctl disable --now adguard-update.timer >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE" "$TIMER_FILE" "$SETTINGS_FILE" "$INSTALL_PATH"
    systemctl daemon-reload
    printf 'AdGuard Home Updater removed. Backups and logs were preserved.\n'
    exit 0
fi

case "$(uname -m)" in
    x86_64 | amd64 | aarch64 | arm64) ;;
    *)
        fail "Unsupported architecture: $(uname -m). Supported: amd64, arm64"
        exit 1
        ;;
esac

existing_version=""
[[ ! -x "$INSTALL_PATH" ]] || existing_version=$("$INSTALL_PATH" --version 2>/dev/null || true)
stored_version=$(stored_setting ADGUARD_UPDATER_SETTINGS_VERSION)
if [[ -n "$existing_version" && "$stored_version" != "$SETTINGS_VERSION" ]]; then
    MIGRATION_NEEDED=true
fi

legacy_timer_enabled=false
systemctl is-enabled --quiet adguard-update.timer 2>/dev/null && legacy_timer_enabled=true

[[ -n "$TIMER_MODE" ]] || TIMER_MODE=$(stored_setting ADGUARD_UPDATER_TIMER)
[[ -n "$SCHEDULE" ]] || SCHEDULE=$(stored_setting ADGUARD_UPDATER_SCHEDULE)
[[ -n "$RUN_TIME" ]] || RUN_TIME=$(stored_setting ADGUARD_UPDATER_TIME)
[[ -n "$WEEKDAY" ]] || WEEKDAY=$(stored_setting ADGUARD_UPDATER_WEEKDAY)
[[ -n "$RANDOM_DELAY" ]] || RANDOM_DELAY=$(stored_setting ADGUARD_UPDATER_RANDOM_DELAY)
[[ -n "$HEALTH_DOMAIN" ]] || HEALTH_DOMAIN=$(stored_setting ADGUARD_HEALTHCHECK_DOMAIN)
[[ -n "$UPDATE_MODE" ]] || UPDATE_MODE=$(stored_setting ADGUARD_UPDATE_MODE)
[[ -n "$RELEASE_DELAY_DAYS" ]] || RELEASE_DELAY_DAYS=$(stored_setting ADGUARD_RELEASE_DELAY_DAYS)
[[ -n "$BACKUP_RETENTION" ]] || BACKUP_RETENTION=$(stored_setting ADGUARD_BACKUP_RETENTION)
[[ -n "$HEALTH_RETRIES" ]] || HEALTH_RETRIES=$(stored_setting ADGUARD_HEALTH_RETRIES)
[[ -n "$HEALTH_TIMEOUT" ]] || HEALTH_TIMEOUT=$(stored_setting ADGUARD_HEALTH_TIMEOUT)
[[ -n "$HEALTH_FAILURE" ]] || HEALTH_FAILURE=$(stored_setting ADGUARD_HEALTH_FAILURE)

if [[ -z "$TIMER_MODE" ]]; then
    $legacy_timer_enabled && TIMER_MODE=enabled || TIMER_MODE=disabled
fi
SCHEDULE=${SCHEDULE:-daily}
RUN_TIME=${RUN_TIME:-03:00}
WEEKDAY=${WEEKDAY:-Sun}
RANDOM_DELAY=${RANDOM_DELAY:-1h}
HEALTH_DOMAIN=${HEALTH_DOMAIN:-example.org}
UPDATE_MODE=${UPDATE_MODE:-automatic}
RELEASE_DELAY_DAYS=${RELEASE_DELAY_DAYS:-0}
BACKUP_RETENTION=${BACKUP_RETENTION:-3}
HEALTH_RETRIES=${HEALTH_RETRIES:-15}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-2}
HEALTH_FAILURE=${HEALTH_FAILURE:-rollback}

if $INTERACTIVE && ! $TIMER_EXPLICIT && [[ -z "$stored_version" ]]; then
    answer=n
    read -r -p "Enable scheduled automatic updates? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] && TIMER_MODE=enabled || TIMER_MODE=disabled
fi
validate_settings

printf 'AdGuard Home Updater installer %s\n' "$INSTALLER_VERSION"
[[ -z "$existing_version" ]] || printf 'Existing installation: %s\n' "$existing_version"
if $MIGRATION_NEEDED; then
    printf 'NOTICE: This release introduces configurable persisted settings.\n'
    printf 'Existing timer state was preserved. Review or regenerate your configuration at https://install.foxly.de.\n'
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/adguard-updater-install.XXXXXXXX")
tag=$(curl --fail --silent --show-error --location --retry 3 "$GITHUB_API/repos/$REPO/releases/latest" | extract_tag)
[[ -n "$tag" ]] || {
    fail "Could not determine latest updater release"
    exit 1
}
base="https://github.com/$REPO/releases/download/$tag"
curl --fail --silent --show-error --location --retry 3 --output "$TMP_DIR/adguard-update" "$base/adguard-update"
curl --fail --silent --show-error --location --retry 3 --output "$TMP_DIR/checksums.txt" "$base/checksums.txt"
expected=$(checksum_for "$TMP_DIR/checksums.txt" adguard-update)
actual=$(sha256sum "$TMP_DIR/adguard-update" | awk '{print $1}')
[[ "$expected" =~ ^[[:xdigit:]]{64}$ && "$expected" == "$actual" ]] ||
    {
        fail "Updater checksum verification failed"
        exit 1
    }

mkdir -p "$(dirname "$INSTALL_PATH")" "$(dirname "$SERVICE_FILE")" "$(dirname "$TIMER_FILE")" "$(dirname "$SETTINGS_FILE")"
install -m 0755 "$TMP_DIR/adguard-update" "$INSTALL_PATH"

cat >"$SETTINGS_FILE" <<EOF
# Managed by the AdGuard Home Updater installer.
ADGUARD_UPDATER_SETTINGS_VERSION=$SETTINGS_VERSION
ADGUARD_UPDATER_TIMER=$TIMER_MODE
ADGUARD_UPDATER_SCHEDULE=$SCHEDULE
ADGUARD_UPDATER_TIME=$RUN_TIME
ADGUARD_UPDATER_WEEKDAY=$WEEKDAY
ADGUARD_UPDATER_RANDOM_DELAY=$RANDOM_DELAY
ADGUARD_HEALTHCHECK_DOMAIN=$HEALTH_DOMAIN
ADGUARD_UPDATE_MODE=$UPDATE_MODE
ADGUARD_RELEASE_DELAY_DAYS=$RELEASE_DELAY_DAYS
ADGUARD_BACKUP_RETENTION=$BACKUP_RETENTION
ADGUARD_HEALTH_RETRIES=$HEALTH_RETRIES
ADGUARD_HEALTH_TIMEOUT=$HEALTH_TIMEOUT
ADGUARD_HEALTH_FAILURE=$HEALTH_FAILURE
EOF
chmod 0644 "$SETTINGS_FILE"

cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Update AdGuard Home and verify DNS health
Documentation=https://github.com/$REPO
Wants=network-online.target
After=network-online.target AdGuardHome.service
ConditionPathIsExecutable=/opt/AdGuardHome/AdGuardHome

[Service]
Type=oneshot
EnvironmentFile=-$SETTINGS_FILE
ExecStart=$INSTALL_PATH --scheduled
User=root
EOF

if [[ "$SCHEDULE" == weekly ]]; then
    ON_CALENDAR="$WEEKDAY *-*-* $RUN_TIME:00"
else
    ON_CALENDAR="*-*-* $RUN_TIME:00"
fi
cat >"$TIMER_FILE" <<EOF
[Unit]
Description=Scheduled AdGuard Home update

[Timer]
OnCalendar=$ON_CALENDAR
Persistent=true
RandomizedDelaySec=$RANDOM_DELAY
AccuracySec=1m

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
if [[ "$TIMER_MODE" == enabled ]]; then
    systemctl enable adguard-update.timer
    systemctl restart adguard-update.timer
    printf 'Updater %s installed; timer enabled (%s, %s, random delay %s).\n' "$tag" "$SCHEDULE" "$RUN_TIME" "$RANDOM_DELAY"
else
    systemctl disable --now adguard-update.timer >/dev/null 2>&1 || true
    printf 'Updater %s installed; scheduled updates are disabled.\n' "$tag"
fi
printf 'Health-check domain: %s\n' "$HEALTH_DOMAIN"
printf 'Update mode: %s; release delay: %s day(s); retained backups: %s\n' \
    "$UPDATE_MODE" "$RELEASE_DELAY_DAYS" "$BACKUP_RETENTION"
printf 'Settings file: %s\n' "$SETTINGS_FILE"
printf 'Validate with: adguard-update --dry-run\n'
