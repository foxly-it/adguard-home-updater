<p align="center">
<img src="assets/banner.png" alt="AdGuard Home Updater">
</p>

# AdGuard Home Bare-Metal Updater

---

## 🌍 Language / Sprache

- 🇬🇧 [English Version](#english)
- 🇩🇪 [Deutsche Version](#deutsch)

---

<a id="english"></a>
# 🇬🇧 English

![Release](https://img.shields.io/github/v/release/foxly-it/adguard-home-updater)
![Downloads](https://img.shields.io/github/downloads/foxly-it/adguard-home-updater/total)
![Shell](https://img.shields.io/badge/script-bash-green)
![Platform](https://img.shields.io/badge/platform-linux-blue)
![Arch](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-informational)
![License](https://img.shields.io/github/license/foxly-it/adguard-home-updater)

Safe and automated updater for **AdGuard Home bare-metal installations**.

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/install.sh | sudo bash
```

---

## Features

- Architecture detection (amd64 / arm64)
- Automatic version check
- Secure download with checksum validation (if available)
- Binary backup + rollback
- Dry-run mode
- Self-update support
- DNS health check with retry logic
- systemd integration

---

## Usage

```bash
sudo adguard-update
```

Check only:

```bash
adguard-update --check
```

Dry-run:

```bash
sudo adguard-update --dry-run
```

---

## Notes

- Uses native binary control:
  
```bash
./AdGuardHome -s stop
./AdGuardHome -s start
```

- Avoids "binary busy" issues
- Skips checksum validation if upstream does not provide one

---

## Logging

```
/var/log/adguard-update.log
```

---

## Troubleshooting

### DNS check fails

```bash
dig @127.0.0.1 google.com
```

### Binary busy

```bash
cd /opt/AdGuardHome
./AdGuardHome -s stop
```

---

<a id="deutsch"></a>
# 🇩🇪 Deutsch

Sicherer und automatisierter Updater für **AdGuard Home Bare-Metal Installationen**.

Dieses Tool richtet sich speziell an **Homelab- und Infrastruktur-Setups**, bei denen Stabilität entscheidend ist.

---

## 🚀 Schnellinstallation

```bash
curl -fsSL https://raw.githubusercontent.com/foxly-it/adguard-home-updater/main/install.sh | sudo bash
```

---

## ⚙️ Features

- Architektur-Erkennung (amd64 / arm64)
- Automatische Versionsprüfung
- Sicherer Download mit Checksum-Prüfung (falls vorhanden)
- Backup der bestehenden Binary
- Automatischer Rollback bei Fehlern
- Dry-Run Modus
- Self-Update Funktion
- DNS Health Check mit Retry-Logik
- systemd Integration

---

## 🧠 Verwendung

Normales Update:

```bash
sudo adguard-update
```

Nur prüfen:

```bash
adguard-update --check
```

Simulation:

```bash
sudo adguard-update --dry-run
```

---

## 🛠️ Technische Hinweise

Das Script nutzt bewusst **keinen systemctl Stop**, sondern:

```bash
cd /opt/AdGuardHome
./AdGuardHome -s stop
```

→ verhindert „binary busy“ Fehler beim Update.

---

## 🧾 Logging

Alle Aktionen werden hier gespeichert:

```
/var/log/adguard-update.log
```

---

## 🧯 Fehlerbehebung

### DNS Test schlägt fehl

```bash
dig @127.0.0.1 google.com
```

---

### Binary lässt sich nicht überschreiben

```bash
cd /opt/AdGuardHome
./AdGuardHome -s stop
```

---

### Keine Checksum verfügbar

Einige Releases enthalten keine `.sha256` Datei.

→ Der Updater überspringt dann die Verifikation automatisch.

---

## 📦 Beispiel Setup

```
Clients
   ↓
AdGuard Home
   ↓
Unbound
   ↓
Internet
```

---

## 📜 Lizenz

MIT License

---

## ⚠️ Hinweis

Dieses Projekt ist **nicht offiziell von AdGuard**.

Nutzung auf eigene Verantwortung.