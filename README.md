<p align="center">
<img src="assets/banner.png" alt="AdGuard Home Updater">
</p>

# AdGuard Home Bare-Metal Updater

![Release](https://img.shields.io/github/v/release/foxly-it/adguard-home-updater)
![Shell](https://img.shields.io/badge/script-bash-green)
![Platform](https://img.shields.io/badge/platform-linux-blue)
![Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-informational)
![AdGuard](https://img.shields.io/badge/AdGuard-Home-68BC71)
![Systemd](https://img.shields.io/badge/automation-systemd-orange)
![License](https://img.shields.io/github/license/foxly-it/adguard-home-updater)

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

# Quick Install

Install the updater with a **single command**:

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/install.sh | sudo bash
```

The installer will:

- install `adguard-update`
- install systemd service
- optionally enable automatic updates

---

# Features

| Feature | Description |
|---|---|
| Architecture detection | Supports `amd64` and `arm64` |
| Automatic version check | Compares installed version with latest upstream release |
| Secure download | Verifies official SHA256 checksum |
| Binary backup | Keeps previous binary |
| Rollback protection | Restores old binary if service fails |
| Dry-run mode | Simulates full update workflow |
| Check mode | Shows if update is available |
| Force update | Reinstalls even if version matches |
| Self update | Updates the updater itself |
| Lockfile protection | Prevents concurrent runs |
| Logging | Writes logs to `/var/log/adguard-update.log` |
| systemd integration | Supports automated update checks |

---

# Why this project exists

AdGuard Home works extremely well as a **bare-metal DNS resolver**, especially on small ARM systems such as Raspberry Pi.

However, updates are usually still performed manually.

Typical manual workflow:

```text
download → extract → stop service → replace binary → start service
```

While simple, this is not ideal for infrastructure services such as DNS.

This project converts the process into a **safe and repeatable workflow with safeguards**.

---

# Requirements

- Linux host
- systemd
- root privileges
- internet access
- AdGuard Home installed in:

```text
/opt/AdGuardHome
```

Required utilities:

```text
curl
tar
sha256sum
systemctl
```

---

# Repository Structure

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
├─ assets
│   └─ banner.png
│
└─ .github
    └─ workflows
        └─ release.yml
```

---

# Usage

## Status

```bash
adguard-update --status
```

---

## Check for update

```bash
adguard-update --check
```

Example output:

```text
Installed version:
  0.107.72

Latest version:
  0.107.73

Status: update available
```

---

## Dry-run

Simulate update workflow:

```bash
sudo adguard-update --dry-run
```

---

## Normal update

```bash
sudo adguard-update
```

---

## Force update

```bash
sudo adguard-update --force
```

---

## Update the updater

```bash
sudo adguard-update --self-update
```

---

# Update Workflow

The updater performs the following sequence:

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
Health Check
      ↓
Rollback on Failure
```

This keeps the process simple, auditable, and safe for infrastructure services.

---

# Downtime

Typical DNS interruption during update:

```text
~300–500 ms
```

Most environments will not notice this due to DNS caching.

For critical homelab setups a secondary resolver is recommended.

Example:

```text
Primary DNS:   192.168.178.4
Secondary DNS: 10.100.0.3
```

---

# Logging

All activity is written to:

```text
/var/log/adguard-update.log
```

Example:

```text
2026-03-11 03:10:01 - Architecture detected: arm64
2026-03-11 03:10:01 - Installed version: 0.107.72
2026-03-11 03:10:01 - Latest version: 0.107.73
2026-03-11 03:10:02 - Downloading release
2026-03-11 03:10:03 - Verifying checksum
2026-03-11 03:10:04 - Installing new binary
2026-03-11 03:10:05 - Update successful
```

---

# systemd Automation

The installer can automatically configure a **systemd timer**.

Check timer:

```bash
systemctl status adguard-update.timer
```

Manual run:

```bash
systemctl start adguard-update.service
```

List timers:

```bash
systemctl list-timers | grep adguard
```

---

# Safety Mechanisms

### Lockfile

```text
/var/run/adguard-update.lock
```

Prevents concurrent update runs.

---

### Binary backup

```text
/opt/AdGuardHome/AdGuardHome.backup
```

---

### Automatic rollback

If the service fails after update, the previous binary is restored automatically.

---

# Example Homelab Architecture

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

# Security Notes

The updater downloads binaries from the **official AdGuard release source** and verifies the SHA256 checksum before installation.

Recommended first run:

```bash
sudo adguard-update --dry-run
```

---

# Roadmap

Possible future improvements:

- cluster aware multi-DNS updates
- AdGuard API health checks
- notification hooks
- release channel support
- changelog integration

---

# License

MIT License

---

# Disclaimer

This project is **not affiliated with AdGuard**.

Use at your own risk.