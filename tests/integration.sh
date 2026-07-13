#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/adguard-updater-test.XXXXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

MOCK_BIN="$TEST_ROOT/bin"
INSTALL_DIR="$TEST_ROOT/AdGuardHome"
CALL_LOG="$TEST_ROOT/calls.log"
SERVICE_STATE="$TEST_ROOT/service.state"
RELEASE_DIR="$TEST_ROOT/release"
mkdir -p "$MOCK_BIN" "$INSTALL_DIR"
: > "$CALL_LOG"
printf 'active\n' > "$SERVICE_STATE"

cat > "$INSTALL_DIR/AdGuardHome" << 'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    --version) printf 'AdGuard Home, version v%s\n' "${MOCK_CURRENT_VERSION:-0.107.76}" ;;
    --check-config) exit 0 ;;
    -s)
        printf 'adguard %s\n' "${2:-}" >> "$MOCK_CALL_LOG"
        case "${2:-}" in
            stop) printf 'inactive\n' > "$MOCK_SERVICE_STATE" ;;
            start) printf 'active\n' > "$MOCK_SERVICE_STATE" ;;
        esac
        ;;
    *) exit 0 ;;
esac
EOF
chmod +x "$INSTALL_DIR/AdGuardHome"
printf 'http:\n  address: 0.0.0.0:3000\n' > "$INSTALL_DIR/AdGuardHome.yaml"

cat > "$MOCK_BIN/curl" << 'EOF'
#!/usr/bin/env bash
output=""
url=""
while (($# > 0)); do
    case "$1" in
        --output | -o)
            output=$2
            shift 2
            ;;
        http*)
            url=$1
            shift
            ;;
        *) shift ;;
    esac
done
if [[ -n "$output" ]]; then
    cp "$MOCK_RELEASE_DIR/${url##*/}" "$output"
    exit 0
fi
printf '{"tag_name":"v%s","published_at":"%s"}\n' \
    "${MOCK_LATEST_VERSION:-0.107.77}" "${MOCK_PUBLISHED_AT:-2026-01-01T00:00:00Z}"
EOF

cat > "$MOCK_BIN/uname" << 'EOF'
#!/usr/bin/env bash
printf 'x86_64\n'
EOF

cat > "$MOCK_BIN/systemctl" << 'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$MOCK_CALL_LOG"
if [[ "${1:-}" == is-active ]]; then
    [[ "$(< "$MOCK_SERVICE_STATE")" == active ]]
elif [[ "${1:-}" == is-enabled ]]; then
    exit 1
fi
EOF

cat > "$MOCK_BIN/dig" << 'EOF'
#!/usr/bin/env bash
printf 'dig %s\n' "$*" >> "$MOCK_CALL_LOG"
exit 0
EOF

cat > "$MOCK_BIN/flock" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN"/*

export PATH="$MOCK_BIN:$PATH"
export MOCK_CALL_LOG="$CALL_LOG"
export MOCK_SERVICE_STATE="$SERVICE_STATE"
export MOCK_RELEASE_DIR="$RELEASE_DIR"
export ADGUARD_INSTALL_DIR="$INSTALL_DIR"
export ADGUARD_UPDATE_LOG="$TEST_ROOT/adguard-update.log"
export ADGUARD_UPDATE_LOCK="$TEST_ROOT/adguard-update.lock"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local file=$1 expected=$2
    grep -Fq -- "$expected" "$file" || fail "Expected '$expected' in $file"
}

run_expect() {
    local expected_status=$1 output=$2
    shift 2
    set +e
    "$@" > "$output" 2>&1
    local actual_status=$?
    set -e
    [[ "$actual_status" -eq "$expected_status" ]] ||
        fail "Expected exit $expected_status, got $actual_status: $(< "$output")"
}

run_expect 10 "$TEST_ROOT/check-update.out" bash "$PROJECT_DIR/adguard-update" --check
assert_contains "$TEST_ROOT/check-update.out" "Update available: 0.107.76 -> 0.107.77"

MOCK_CURRENT_VERSION=0.107.77 run_expect 0 "$TEST_ROOT/check-current.out" \
    bash "$PROJECT_DIR/adguard-update" --check
assert_contains "$TEST_ROOT/check-current.out" "AdGuard Home is up to date"

mkdir -p "$RELEASE_DIR/build/AdGuardHome"
cat > "$RELEASE_DIR/build/AdGuardHome/AdGuardHome" << 'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    --version) printf 'AdGuard Home, version v0.107.77\n' ;;
    --check-config) exit 0 ;;
    -s)
        printf 'adguard %s\n' "${2:-}" >> "$MOCK_CALL_LOG"
        case "${2:-}" in
            stop) printf 'inactive\n' > "$MOCK_SERVICE_STATE" ;;
            start) printf 'active\n' > "$MOCK_SERVICE_STATE" ;;
        esac
        ;;
esac
EOF
chmod +x "$RELEASE_DIR/build/AdGuardHome/AdGuardHome"
tar -czf "$RELEASE_DIR/AdGuardHome_linux_amd64.tar.gz" -C "$RELEASE_DIR/build" AdGuardHome
(
    cd "$RELEASE_DIR"
    sha256sum AdGuardHome_linux_amd64.tar.gz > checksums.txt
)

before_hash=$(sha256sum "$INSTALL_DIR/AdGuardHome" | awk '{print $1}')
run_expect 0 "$TEST_ROOT/dry-run.out" bash "$PROJECT_DIR/adguard-update" --dry-run
after_hash=$(sha256sum "$INSTALL_DIR/AdGuardHome" | awk '{print $1}')
[[ "$before_hash" == "$after_hash" ]] || fail "Dry-run changed the AdGuard Home binary"
[[ ! -s "$CALL_LOG" ]] || fail "Dry-run called a service or DNS command"
[[ ! -e "$TEST_ROOT/adguard-update.log" ]] || fail "Dry-run created a log file"
assert_contains "$TEST_ROOT/dry-run.out" "no files or services were changed"

run_expect 2 "$TEST_ROOT/unknown.out" bash "$PROJECT_DIR/adguard-update" --not-a-real-option
assert_contains "$TEST_ROOT/unknown.out" "Unknown option"

run_expect 0 "$TEST_ROOT/version.out" bash "$PROJECT_DIR/adguard-update" --version
assert_contains "$TEST_ROOT/version.out" "AdGuard Home Updater"

run_expect 0 "$TEST_ROOT/installer-help.out" bash "$PROJECT_DIR/install.sh" --help
assert_contains "$TEST_ROOT/installer-help.out" "--enable-timer"
assert_contains "$TEST_ROOT/installer-help.out" "--install-adguard"

if ((EUID == 0)); then
    : > "$CALL_LOG"
    run_expect 0 "$TEST_ROOT/scheduled-notify.out" env ADGUARD_UPDATE_MODE=notify \
        bash "$PROJECT_DIR/adguard-update" --scheduled
    assert_contains "$TEST_ROOT/scheduled-notify.out" "automatic installation is disabled"
    [[ ! -s "$CALL_LOG" ]] || fail "Notify mode changed the service"

    run_expect 0 "$TEST_ROOT/scheduled-delay.out" env \
        ADGUARD_UPDATE_MODE=automatic ADGUARD_RELEASE_DELAY_DAYS=7 \
        MOCK_PUBLISHED_AT=2099-01-01T00:00:00Z \
        bash "$PROJECT_DIR/adguard-update" --scheduled
    assert_contains "$TEST_ROOT/scheduled-delay.out" "Release delay active"

    : > "$CALL_LOG"
    run_expect 0 "$TEST_ROOT/update.out" bash "$PROJECT_DIR/adguard-update"
    assert_contains "$TEST_ROOT/update.out" "SHA-256 checksum verified"
    assert_contains "$TEST_ROOT/update.out" "Configuration check passed"
    assert_contains "$TEST_ROOT/update.out" "updated successfully to 0.107.77"
    [[ "$(< "$SERVICE_STATE")" == active ]] || fail "Service was not active after update"
    find "$INSTALL_DIR/adguard-update-backups" -name AdGuardHome -type f | grep -q . || fail "Binary backup is missing"
    [[ "$("$INSTALL_DIR/AdGuardHome" --version)" == *v0.107.77 ]] || fail "New binary was not installed"

    run_expect 0 "$TEST_ROOT/list-backups.out" bash "$PROJECT_DIR/adguard-update" --list-backups
    assert_contains "$TEST_ROOT/list-backups.out" "adguard-update-backups"
    run_expect 0 "$TEST_ROOT/rollback.out" bash "$PROJECT_DIR/adguard-update" --rollback
    assert_contains "$TEST_ROOT/rollback.out" "Rollback completed"
    [[ "$("$INSTALL_DIR/AdGuardHome" --version)" == *v0.107.76 ]] || fail "Rollback did not restore the old binary"

    cp "$PROJECT_DIR/adguard-update" "$RELEASE_DIR/adguard-update"
    (
        cd "$RELEASE_DIR"
        sha256sum adguard-update >> checksums.txt
    )
    updater_install_path="$TEST_ROOT/usr/local/sbin/adguard-update"
    service_file="$TEST_ROOT/etc/systemd/system/adguard-update.service"
    timer_file="$TEST_ROOT/etc/systemd/system/adguard-update.timer"
    settings_file="$TEST_ROOT/etc/default/adguard-update"
    mkdir -p "$(dirname "$updater_install_path")"
    cp "$PROJECT_DIR/adguard-update" "$updater_install_path"
    chmod +x "$updater_install_path"
    : > "$CALL_LOG"
    run_expect 0 "$TEST_ROOT/install.out" env \
        UPDATER_INSTALL_PATH="$updater_install_path" \
        UPDATER_SERVICE_FILE="$service_file" \
        UPDATER_TIMER_FILE="$timer_file" \
        UPDATER_SETTINGS_FILE="$settings_file" \
        bash "$PROJECT_DIR/install.sh" --no-interactive
    [[ -x "$updater_install_path" ]] || fail "Installer did not install an executable updater"
    [[ -f "$service_file" && -f "$timer_file" && -f "$settings_file" ]] || fail "Installer output is incomplete"
    assert_contains "$TEST_ROOT/install.out" "scheduled updates are disabled"
    assert_contains "$TEST_ROOT/install.out" "introduces configurable persisted settings"

    fresh_adguard_dir="$TEST_ROOT/fresh/AdGuardHome"
    fresh_updater_path="$TEST_ROOT/fresh/usr/local/sbin/adguard-update"
    fresh_service_file="$TEST_ROOT/fresh/etc/systemd/system/adguard-update.service"
    fresh_timer_file="$TEST_ROOT/fresh/etc/systemd/system/adguard-update.timer"
    fresh_settings_file="$TEST_ROOT/fresh/etc/default/adguard-update"

    run_expect 1 "$TEST_ROOT/install-adguard-declined.out" env \
        ADGUARD_INSTALL_DIR="$fresh_adguard_dir" \
        UPDATER_INSTALL_PATH="$fresh_updater_path" \
        UPDATER_SERVICE_FILE="$fresh_service_file" \
        UPDATER_TIMER_FILE="$fresh_timer_file" \
        UPDATER_SETTINGS_FILE="$fresh_settings_file" \
        bash "$PROJECT_DIR/install.sh" --no-interactive --install-adguard no
    assert_contains "$TEST_ROOT/install-adguard-declined.out" "AdGuard Home is required"
    [[ ! -e "$fresh_updater_path" ]] || fail "Updater was installed without AdGuard Home"

    : > "$CALL_LOG"
    run_expect 0 "$TEST_ROOT/install-adguard.out" env \
        ADGUARD_INSTALL_DIR="$fresh_adguard_dir" \
        UPDATER_INSTALL_PATH="$fresh_updater_path" \
        UPDATER_SERVICE_FILE="$fresh_service_file" \
        UPDATER_TIMER_FILE="$fresh_timer_file" \
        UPDATER_SETTINGS_FILE="$fresh_settings_file" \
        bash "$PROJECT_DIR/install.sh" --no-interactive --install-adguard yes
    [[ -x "$fresh_adguard_dir/AdGuardHome" ]] || fail "AdGuard Home was not installed"
    [[ -x "$fresh_updater_path" ]] || fail "Updater was not installed after AdGuard Home"
    assert_contains "$CALL_LOG" "adguard install"
    assert_contains "$TEST_ROOT/install-adguard.out" "AdGuard Home SHA-256 checksum verified"
    assert_contains "$TEST_ROOT/install-adguard.out" "Complete the initial setup"
    assert_contains "$fresh_service_file" "ConditionPathIsExecutable=$fresh_adguard_dir/AdGuardHome"

    run_expect 0 "$TEST_ROOT/install-custom.out" env \
        UPDATER_INSTALL_PATH="$updater_install_path" \
        UPDATER_SERVICE_FILE="$service_file" \
        UPDATER_TIMER_FILE="$timer_file" \
        UPDATER_SETTINGS_FILE="$settings_file" \
        bash "$PROJECT_DIR/install.sh" --no-interactive \
        --timer enabled --schedule weekly --time 04:15 --weekday Sat \
        --random-delay 30m --health-domain dns.example.org \
        --update-mode automatic --release-delay 7 --backup-retention 5 \
        --health-retries 20 --health-timeout 3 --health-failure rollback
    assert_contains "$settings_file" "ADGUARD_UPDATER_SETTINGS_VERSION=3"
    assert_contains "$settings_file" "ADGUARD_HEALTHCHECK_DOMAIN=dns.example.org"
    assert_contains "$settings_file" "ADGUARD_RELEASE_DELAY_DAYS=7"
    assert_contains "$settings_file" "ADGUARD_BACKUP_RETENTION=5"
    assert_contains "$timer_file" "OnCalendar=Sat *-*-* 04:15:00"
    assert_contains "$timer_file" "RandomizedDelaySec=30m"
    assert_contains "$TEST_ROOT/install-custom.out" "timer enabled (weekly, 04:15, random delay 30m)"

    run_expect 1 "$TEST_ROOT/install-invalid.out" env \
        UPDATER_INSTALL_PATH="$updater_install_path" \
        UPDATER_SERVICE_FILE="$service_file" \
        UPDATER_TIMER_FILE="$timer_file" \
        UPDATER_SETTINGS_FILE="$settings_file" \
        bash "$PROJECT_DIR/install.sh" --no-interactive --time 99:99
    assert_contains "$TEST_ROOT/install-invalid.out" "24-hour HH:MM format"
fi

printf 'Integration tests passed.\n'
