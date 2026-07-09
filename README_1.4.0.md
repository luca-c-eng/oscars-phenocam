# oscars-phenocam — software v1.4.0

Automated PhenoCam acquisition stack for Raspberry Pi OS Lite.

Validated targets for v1.4.0:

- Raspberry Pi 3B+ + Raspberry Pi Camera Module 3 / Camera V3 NoIR
- Raspberry Pi Zero 2 W + Raspberry Pi Camera Module 3 / Camera V3 NoIR

The software captures VIS JPEG images, builds `.meta` sidecar files, queues them in RAM/USB/SD storage, and uploads them through FTP and/or SFTP.

## Directory layout

```text
software/
├── bin/        # executable entrypoints called by systemd or manually
├── scripts/    # reusable logic modules sourced by bin scripts
├── config/     # example configuration files
├── systemd/    # systemd units, timers, mount unit, udev rules
├── docs/       # installation, configuration, operations notes
├── README.md
├── ReadME.txt
├── CHANGELOG.md
├── VERSION
└── VERSIONS.txt
```

## Main runtime paths

```text
/usr/local/lib/phenocam/       installed software
/etc/phenocam/                 local configuration
/run/phenocam/                 RAMDISK queue and staging area
/var/lib/phenocam/queue/       SD-card fallback queue
/var/log/phenocam/phenocam.log runtime log
```

`/run/phenocam` is a `tmpfs`: it is fast and volatile. Files inside it disappear if the RAMDISK is unmounted or the board reboots. Files in `/var/lib/phenocam/queue` persist on the SD card.

## Clean install

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/dev/v1.4.0/install.sh | bash
```

The installer prepares the runtime RAMDISK, deploys services, creates configuration files, and keeps production timers disabled until the station is configured.

After editing `/etc/phenocam/settings.txt` and upload credentials, start production:

```bash
sudo systemctl enable --now phenocam-capture.timer phenocam-upload.timer
```

See [`docs/CLEAN_INSTALL.md`](docs/CLEAN_INSTALL.md) for a complete fresh-install workflow.

## Configuration files

```text
/etc/phenocam/settings.txt          main positional configuration
/etc/phenocam/ftp_credentials.txt   FTP credentials, optional
/etc/phenocam/server.txt            SFTP server list, optional
/etc/phenocam/known_hosts           SFTP known_hosts file, optional
/etc/phenocam/keys/phenocam_key     SFTP private key, optional
```

FTP and SFTP are independent:

- FTP is enabled only when `ftp_credentials.txt` contains 5 effective non-comment lines.
- SFTP is enabled only when `server.txt` contains at least one effective non-comment line.
- An empty or comment-only `server.txt` must not trigger SFTP.
- FTP may use any provider-defined port, including port `22`, while still using the `ftp://` protocol.

See [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md).

## Timers

```bash
systemctl list-timers 'phenocam-*' --all
```

Default timers:

```text
phenocam-capture.timer   captures at minute :00 and :30
phenocam-upload.timer    drains queues every 9 minutes after boot/activity
```

## Diagnostics

```bash
sudo tail -80 /var/log/phenocam/phenocam.log
sudo find /run/phenocam /var/lib/phenocam -type f \( -name '*.jpg' -o -name '*.meta' \) -ls 2>/dev/null
systemctl status phenocam-init.service phenocam-capture.timer phenocam-upload.timer --no-pager -l
```

A healthy capture/upload cycle looks like:

```text
Capture VIS -> /run/phenocam/staging/<site>_YYYY_MM_DD_HHMMSS.jpg
Build meta -> /run/phenocam/staging/<site>_YYYY_MM_DD_HHMMSS.meta
Enqueued: <base> -> /run/phenocam/queue
FTP uploaded and removed: <base> from /run/phenocam/queue
```
---
## v1.4.0 Zero 2 W lessons included

This branch includes fixes from the Raspberry Pi Zero 2 W validation session:

- RAMDISK ownership is made persistent through uid/gid-aware mount options.
- Dynamic RAMDISK sizing is moved out of fragile inline systemd Bash into `phenocam-init-ramdisk.sh`.
- `phenocam-capture.service` has `TimeoutStartSec=300`.
- `capture_vis.sh` treats `CAPTURE_TIMEOUT=30000` as rpicam warm-up time, not as an OS-level guard.
- `capture_vis.sh` uses `-n`/nopreview for headless installs and a wider external guard timeout.
- FTP accepts provider-defined ports, including `22`, without converting to SFTP.
- SFTP is skipped when `server.txt` has no effective configuration.
---

```markdown
## Runtime health metadata from v1.5.0

PhenoCam records Raspberry Pi system health in every `.meta` file:

```text
[system_health]
soc_temp_c=48.2
throttled_hex=0x0
arm_clock_mhz=1000
```
to inspect current temperature, undervoltage and throttling state:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

