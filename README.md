<p align="center">
  <img src="docs/assets/banner.webp" width="600" alt="AdGuard Home Updater">
</p>

# AdGuard Home Bare-Metal Updater

A security-focused update tool for supported AdGuard Home bare-metal installations.

[English](#english-documentation) | [Deutsch](#deutsche-dokumentation) | [Installation website](https://install.foxly.de)

## English documentation

### Overview

The updater installs verified stable AdGuard Home releases on Linux systems running systemd. The installer checks whether a supported AdGuard Home installation exists and can install the latest official stable release first with explicit permission. Before replacing an installed binary, the updater verifies the official SHA-256 checksum, checks the existing configuration with the new release, and creates a local backup. A failed service start or DNS health check triggers an automatic rollback.

This is an independent community project and is not affiliated with or maintained by AdGuard.

### Supported systems

| Component | Supported |
| --- | --- |
| Operating system | Linux with systemd |
| Architectures | amd64, arm64 |
| Installation type | Bare-metal installation under `/opt/AdGuardHome` |
| Release channel | Latest stable GitHub release |

Required commands are `curl`, `tar`, `sha256sum`, `flock`, `systemctl`, `dig`, and standard GNU utilities. On Debian and Ubuntu, `dig` is provided by the `dnsutils` package.

### Installation

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash
```

The installer does not enable automatic updates by default. The [installation configurator](https://install.foxly.de) generates a command with all supported settings. Example for a weekly update:

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash -s -- \
  --no-interactive --install-adguard no --timer enabled --schedule weekly --time 04:15 \
  --weekday Sat --random-delay 30m --health-domain example.org
```

| Installer option | Values | Default |
| --- | --- | --- |
| `--install-adguard` | `yes`, `no` | Ask when missing |
| `--timer` | `enabled`, `disabled` | `disabled` |
| `--schedule` | `daily`, `weekly` | `daily` |
| `--time` | Local time in `HH:MM` | `03:00` |
| `--weekday` | `Mon` through `Sun` | `Sun` |
| `--random-delay` | `0` or a systemd duration | `1h` |
| `--health-domain` | Valid DNS name | `example.org` |
| `--update-mode` | `automatic`, `notify` | `automatic` |
| `--release-delay` | `0` to `30` days | `0` |
| `--backup-retention` | `1` to `10` backups | `3` |
| `--health-retries` | `1` to `60` attempts | `15` |
| `--health-timeout` | `1` to `30` seconds | `2` |
| `--health-failure` | `rollback`, `warn` | `rollback` |

Settings are validated and stored in `/etc/default/adguard-update`. Later installer runs reuse them unless an option explicitly overrides a value. Legacy installations preserve their existing timer state and receive a migration notice when new settings become available.

Before installing the updater, the installer checks for `/opt/AdGuardHome/AdGuardHome`. If it is missing, an interactive run asks whether AdGuard Home should be installed. `--install-adguard yes` downloads the exact latest stable release from the [official AdGuard Home repository](https://github.com/AdguardTeam/AdGuardHome), verifies its published SHA-256 checksum and version, and installs its native system service. `--install-adguard no` aborts without installing the updater when AdGuard Home is missing. A newly installed AdGuard Home instance must then be configured through its setup wizard at `http://SERVER-IP:3000`.

### Commands

```bash
adguard-update --check             # Check without system changes
adguard-update --dry-run           # Validate the update plan
sudo adguard-update                # Install the latest stable release
sudo adguard-update --force        # Reinstall the current release
adguard-update --status            # Show versions and service status
sudo adguard-update --self-update  # Update this tool
adguard-update --list-backups      # List versioned recovery points
sudo adguard-update --rollback     # Restore the newest backup
```

`--check` returns status `0` when current and status `10` when an update is available.

### Update safeguards

- Release-specific archive and `checksums.txt` from the same official GitHub release
- Mandatory SHA-256 verification
- Safe extraction into a private temporary directory
- Binary version and configuration validation
- Binary and configuration backups under `/opt/AdGuardHome/adguard-update-backups`
- Native service control, systemd and DNS health checks, and automatic rollback
- Exclusive process lock and guaranteed temporary-file cleanup

Logs are written to `/var/log/adguard-update.log` and the systemd journal.

### Uninstallation

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash -s -- uninstall
```

Logs and AdGuard Home backups are deliberately preserved.

## Deutsche Dokumentation

### Überblick

Der Updater installiert verifizierte stabile AdGuard-Home-Releases auf Linux-Systemen mit systemd. Der Installer prüft, ob eine unterstützte AdGuard-Home-Installation vorhanden ist, und kann mit ausdrücklicher Zustimmung zuerst das aktuelle offizielle stabile Release installieren. Vor dem Austausch einer installierten Programmdatei prüft der Updater die offizielle SHA-256-Prüfsumme, validiert die vorhandene Konfiguration mit dem neuen Release und erstellt ein lokales Backup. Schlägt der Dienststart oder DNS-Healthcheck fehl, wird automatisch die vorherige Version wiederhergestellt.

Dies ist ein unabhängiges Community-Projekt und wird weder von AdGuard betrieben noch offiziell unterstützt.

### Unterstützte Systeme

| Komponente | Unterstützung |
| --- | --- |
| Betriebssystem | Linux mit systemd |
| Architekturen | amd64, arm64 |
| Installationstyp | Bare-Metal-Installation unter `/opt/AdGuardHome` |
| Release-Kanal | Aktuelles stabiles GitHub-Release |

Benötigt werden `curl`, `tar`, `sha256sum`, `flock`, `systemctl`, `dig` und übliche GNU-Werkzeuge. Unter Debian und Ubuntu wird `dig` durch das Paket `dnsutils` bereitgestellt.

### Installation

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash
```

Automatische Updates sind standardmäßig deaktiviert. Der [Installationskonfigurator](https://install.foxly.de) erzeugt einen Befehl mit allen unterstützten Einstellungen. Beispiel für ein wöchentliches Update:

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash -s -- \
  --no-interactive --install-adguard no --timer enabled --schedule weekly --time 04:15 \
  --weekday Sat --random-delay 30m --health-domain example.org
```

| Installer-Option | Werte | Standard |
| --- | --- | --- |
| `--install-adguard` | `yes`, `no` | Bei Fehlen nachfragen |
| `--timer` | `enabled`, `disabled` | `disabled` |
| `--schedule` | `daily`, `weekly` | `daily` |
| `--time` | Lokale Uhrzeit als `HH:MM` | `03:00` |
| `--weekday` | `Mon` bis `Sun` | `Sun` |
| `--random-delay` | `0` oder eine systemd-Zeitangabe | `1h` |
| `--health-domain` | Gültiger DNS-Name | `example.org` |
| `--update-mode` | `automatic`, `notify` | `automatic` |
| `--release-delay` | `0` bis `30` Tage | `0` |
| `--backup-retention` | `1` bis `10` Backups | `3` |
| `--health-retries` | `1` bis `60` Versuche | `15` |
| `--health-timeout` | `1` bis `30` Sekunden | `2` |
| `--health-failure` | `rollback`, `warn` | `rollback` |

Die Einstellungen werden validiert und unter `/etc/default/adguard-update` gespeichert. Spätere Installer-Aufrufe verwenden sie erneut, sofern eine Option den Wert nicht ausdrücklich überschreibt. Bei Legacy-Installationen bleibt der vorhandene Timerstatus erhalten; neue Einstellungsmöglichkeiten werden durch einen Migrationshinweis angekündigt.

Vor der Updater-Installation prüft der Installer `/opt/AdGuardHome/AdGuardHome`. Fehlt die Datei, fragt ein interaktiver Aufruf, ob AdGuard Home installiert werden soll. `--install-adguard yes` lädt das exakte aktuelle stabile Release aus dem [offiziellen AdGuard-Home-Repository](https://github.com/AdguardTeam/AdGuardHome), prüft die veröffentlichte SHA-256-Summe und Version und installiert den nativen Systemdienst. `--install-adguard no` bricht bei fehlendem AdGuard Home ab, ohne den Updater zu installieren. Eine neue AdGuard-Home-Installation muss anschließend über den Einrichtungsassistenten unter `http://SERVER-IP:3000` konfiguriert werden.

### Befehle

```bash
adguard-update --check             # Ohne Systemänderungen prüfen
adguard-update --dry-run           # Updateplan validieren
sudo adguard-update                # Aktuelles stabiles Release installieren
sudo adguard-update --force        # Aktuelles Release erneut installieren
adguard-update --status            # Versions- und Dienststatus anzeigen
sudo adguard-update --self-update  # Updater aktualisieren
adguard-update --list-backups      # Wiederherstellungspunkte anzeigen
sudo adguard-update --rollback     # Neuestes Backup wiederherstellen
```

`--check` liefert Status `0`, wenn die Installation aktuell ist, und Status `10`, wenn ein Update verfügbar ist.

### Sicherheitsmechanismen

- Release-genaues Archiv und `checksums.txt` aus demselben offiziellen GitHub-Release
- Verpflichtende SHA-256-Prüfung
- Sicheres Entpacken in ein privates temporäres Verzeichnis
- Validierung von Binary-Version und Konfiguration
- Programmdatei- und Konfigurationsbackups unter `/opt/AdGuardHome/adguard-update-backups`
- Native Dienststeuerung, systemd- und DNS-Healthchecks sowie automatischer Rollback
- Exklusive Prozesssperre und garantierte Bereinigung temporärer Dateien

Protokolle werden unter `/var/log/adguard-update.log` und im systemd-Journal gespeichert.

### Deinstallation

```bash
curl -fsSL https://install.foxly.de/install.sh | sudo bash -s -- uninstall
```

Protokolle und AdGuard-Home-Backups bleiben bewusst erhalten.

## Development

```bash
bash -n adguard-update install.sh docs/install.sh tests/integration.sh
shellcheck -x adguard-update install.sh docs/install.sh tests/integration.sh
shfmt -i 4 -ci -sr -d adguard-update install.sh docs/install.sh tests/integration.sh
bash tests/integration.sh
```

## License

MIT License. See [LICENSE](LICENSE).
