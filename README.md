<p align="center">
<img src="assets/banner.png" alt="AdGuard Home Updater">
</p>

# AdGuard Home Bare-Metal Updater

![Shell](https://img.shields.io/badge/script-bash-green)
![Platform](https://img.shields.io/badge/platform-linux-blue)
![Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-informational)
![AdGuard](https://img.shields.io/badge/AdGuard-Home-68BC71)
![Systemd](https://img.shields.io/badge/automation-systemd-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

Safe and automated updater for **AdGuard Home bare-metal installations**.

This project provides a small but robust update utility for AdGuard Home when installed directly on a Linux host without Docker. It is designed for **homelab DNS infrastructure**, where reliability matters more than flashy features.

The updater focuses on a safe workflow:

- version check
- secure download
- SHA256 verification
- binary backup
- rollback on failure
- optional automation via systemd timer

---

## Why this project exists

AdGuard Home works very well as a bare-metal DNS service, especially on small ARM systems like Raspberry Pi.  
However, binary updates are often still handled manually.

A typical manual update process usually looks like this:

```text
download → extract → stop service → replace binary → start service
```

That works, but it is not ideal for infrastructure services such as DNS.

This project turns that process into a safer and repeatable workflow with proper safeguards.

---

## Features

| Feature | Description |
|---|---|
| Architecture detection | Supports `amd64` and `arm64` |
| Automatic version check | Compares installed version with latest upstream release |
| Secure download | Verifies the official SHA256 checksum |
| Binary backup | Keeps a backup of the previous binary |
| Rollback protection | Restores the old binary if the service fails after update |
| Dry-run mode | Simulates the full workflow without changing the system |
| Force update | Reinstalls even if the version is already current |
| Lockfile protection | Prevents concurrent update runs |
| Logging | Writes update logs to `/var/log/adguard-update.log` |
| systemd integration | Supports automated update checks via timer |

---

## Intended use case

This project is intended for:

- AdGuard Home bare-metal installations
- Raspberry Pi based DNS resolvers
- homelab infrastructure
- small Linux servers with systemd
- setups where Docker is not used for AdGuard Home

This project is **not** intended to replace package-manager based installations.

---

## Requirements

- Linux host with `systemd`
- AdGuard Home installed in:

```text
/opt/AdGuardHome
```

- root privileges
- internet access
- `curl`, `tar`, `sha256sum`, `systemctl`, `ss`

---

## Repository structure

```text
adguard-home-updater
│
├─ adguard-update
├─ install.sh
├─ README.md
├─ LICENSE
├─ .gitignore
│
├─ docs
│   └─ architecture.md
│
└─ .github
    └─ workflows
        └─ release.yml
```

---

## Quick install

Install the updater script, the systemd service, and the timer:

```bash
curl -s https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/install.sh | sudo bash
```

The installer will ask whether automatic updates should be enabled immediately.

---

## Manual installation

Move the updater to the standard admin tools location:

```bash
sudo mv adguard-update /usr/local/sbin/
sudo chmod +x /usr/local/sbin/adguard-update
```

Verify installation:

```bash
which adguard-update
```

Expected output:

```text
/usr/local/sbin/adguard-update
```

---

## Usage

### Dry-run

Simulate the update workflow without changing the system:

```bash
sudo adguard-update --dry-run
```

### Normal update

Run the updater normally:

```bash
sudo adguard-update
```

### Force update

Force reinstall even when the installed version already matches the latest upstream version:

```bash
sudo adguard-update --force
```

---

## Update workflow

The updater uses the following sequence:

```text
Version Check
      ↓
Download Release
      ↓
Download SHA256 File
      ↓
Verify Checksum
      ↓
Extract Archive
      ↓
Stop AdGuard Home
      ↓
Backup Current Binary
      ↓
Install New Binary
      ↓
Start AdGuard Home
      ↓
DNS Health Check
      ↓
Rollback on Failure
```

This keeps the process simple, auditable, and safe for infrastructure services.

---

## Downtime

Typical DNS interruption during an update is very small:

```text
~300–500 ms
```

In most environments this is hidden by DNS caching and retry behavior.

For production-style homelabs, running a second DNS server is still recommended.

Example:

```text
Primary DNS:   192.168.178.4
Secondary DNS: 10.100.0.3
```

---

## Logging

All updater activity is written to:

```text
/var/log/adguard-update.log
```

Example log output:

```text
2026-03-11 03:10:01 - Architecture detected: arm64
2026-03-11 03:10:01 - Installed version: 0.107.72
2026-03-11 03:10:01 - Latest version: 0.107.73
2026-03-11 03:10:02 - Downloading release
2026-03-11 03:10:03 - Downloading checksum
2026-03-11 03:10:03 - Verifying SHA256 checksum
2026-03-11 03:10:03 - Installing new binary
2026-03-11 03:10:04 - Update successful
```

---

## systemd automation

The project supports automated update checks through systemd.

### Service file

Create:

```bash
sudo nano /etc/systemd/system/adguard-update.service
```

```ini
[Unit]
Description=AdGuard Home Update Check
Documentation=https://github.com/foxly-it/adguard-home-updater

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/adguard-update
User=root
```

### Timer file

Create:

```bash
sudo nano /etc/systemd/system/adguard-update.timer
```

```ini
[Unit]
Description=Daily AdGuard Home Update Check

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h
AccuracySec=10m

[Install]
WantedBy=timers.target
```

### Enable the timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now adguard-update.timer
```

Check timer status:

```bash
systemctl list-timers | grep adguard
```

Show logs:

```bash
journalctl -u adguard-update.service
```

---

## Safety mechanisms

### Lockfile

A lockfile prevents concurrent execution:

```text
/var/run/adguard-update.lock
```

This protects against accidental parallel runs, for example from manual execution and a systemd timer at the same time.

### Binary backup

Before replacing the binary, the updater creates:

```text
/opt/AdGuardHome/AdGuardHome.backup
```

### Automatic rollback

If the updated service fails to come back cleanly, the updater restores the previous binary automatically.

### DNS health check

After restart, the updater verifies:

- that the AdGuard Home service is active
- that DNS is listening on port `53`

Only then is the update considered successful.

---

## Example bare-metal setup

```text
Clients
   ↓
AdGuard Home
   ↓
Unbound
   ↓
Internet DNS hierarchy
```

Updater integration:

```text
AdGuard Home
     │
     └── adguard-update
           ├─ version check
           ├─ secure download
           ├─ checksum verification
           ├─ binary replacement
           └─ rollback protection
```

---

## Security notes

This updater downloads binaries from the official AdGuard release location and verifies the published SHA256 checksum before installation.

Even with that safeguard, infrastructure updates should still be tested in your own environment first.

Recommended first run:

```bash
sudo adguard-update --dry-run
```

---

## Roadmap

Possible future improvements:

- cluster-aware multi-DNS update orchestration
- AdGuard API health checks
- notification hooks
- release channel support
- auto-generated changelog support
- install/uninstall helper improvements

---

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.

---

## Disclaimer

This project is **not affiliated with AdGuard**.

Use at your own risk.