<p align="center">
<img src="assets/banner.png" alt="AdGuard Home Updater">
</p>

# AdGuard Home Bare-Metal Updater

![Release](https://img.shields.io/github/v/release/foxly-it/adguard-home-updater)
![Downloads](https://img.shields.io/github/downloads/foxly-it/adguard-home-updater/total)
![Shell](https://img.shields.io/badge/script-bash-green)
![Platform](https://img.shields.io/badge/platform-linux-blue)
![Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-informational)
![License](https://img.shields.io/github/license/foxly-it/adguard-home-updater)

Safe and automated updater for **AdGuard Home bare-metal installations**.

This project provides a small but robust update utility for AdGuard Home when installed directly on a Linux host without Docker.  
It is designed for **homelab DNS infrastructure**, where reliability matters more than flashy features.

---

# Quick Install

# CLI Preview

<p align="center">
<img src="assets/cli-demo.svg">
</p>

Install the updater with a **single command**:

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/install.sh | sudo bash
```

The installer will:

- install `adguard-update`
- install systemd service
- optionally enable automatic updates

---

# Quick Test (Dry-Run without installation)

Run the updater **without installing it**:

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/adguard-update | sudo bash -s -- --dry-run
```

Check if an update is available:

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/adguard-update | sudo bash -s -- --check
```

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
| DNS health check | Verifies port 53 and performs DNS query test |
| Lockfile protection | Prevents concurrent runs |
| Logging | Writes logs to `/var/log/adguard-update.log` |
| systemd integration | Supports automated update checks |

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

```
Installed version:
  0.107.72

Latest version:
  0.107.73

Status: update available
```

---

## Dry-run

Simulate the update workflow:

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

```
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

# Logging

All activity is written to:

```
/var/log/adguard-update.log
```

Example log output:

```
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

Check timer status:

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

```
/var/run/adguard-update.lock
```

Prevents concurrent update runs.

---

### Binary backup

```
/opt/AdGuardHome/AdGuardHome.backup
```

---

### Automatic rollback

If the service fails after update, the previous binary is restored automatically.

---

# Example Homelab Architecture

```
Clients
   ↓
AdGuard Home
   ↓
Unbound
   ↓
Internet DNS hierarchy
```

Updater integration:

```
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

# Requirements

- Linux host
- systemd
- root privileges
- internet access

AdGuard Home installed in:

```
/opt/AdGuardHome
```

Required utilities:

```
curl
tar
sha256sum
systemctl
ss
```

---

# License

MIT License

---

# Disclaimer

This project is **not affiliated with AdGuard**.

Use at your own risk.