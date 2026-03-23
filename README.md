# oscars-phenocam

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.2.2-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System — PhenoCam Software**

Raspberry Pi-based phenological camera system for automated image acquisition
and upload. Part of the [OSCARS](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system)
Open Science project (EU grant 101129751).

---

## Overview

This software turns a Raspberry Pi 3B+ with a Camera Module 3 into an
autonomous phenological camera station. It captures images at scheduled
intervals, builds rich metadata sidecar files, and uploads everything to
a remote server — all without human intervention.

**Key features:**

- Scheduled captures at :00 and :30 of every hour (configurable time window)
- Rich `.meta` sidecar files with system info, fixed capture parameters, and full EXIF data
- 3-level queue: RAMDISK (200MB) → USB drive → SD card, with configurable thresholds
- FTP upload via `curl` (user + password, passive mode, date-based subfolders)
- SFTP upload with ed25519 SSH key (infrastructure ready, server TBD)
- USB hot-plug: automatic detection on insertion and safe handling on removal
- First-boot health check: automatic capture + upload cycle on every startup
- systemd security hardening (NoNewPrivileges, ProtectSystem, MemoryDenyWriteExecute)
- Diagnostic scripts for camera, network, RAMDISK and upload status

---

## Hardware Requirements

| Component | Tested version |
|-----------|---------------|
| Board | Raspberry Pi 3B+ |
| Camera | Raspberry Pi Camera Module 3 (imx708) |
| Storage | MicroSD Industrial 8GB, class 10+ |
| OS | Raspberry Pi OS 64-bit Lite — Debian 13 trixie (2025-12-04) |

Flash the SD card using **Raspberry Pi Imager v2.0.6**:
- Select: *Raspberry Pi OS (Other) → Raspberry Pi OS Lite (64-bit)*
- Compatible with Raspberry Pi 3/4/400/5

---

## Software Dependencies

All dependencies are available via `apt` on Raspberry Pi OS Lite:

| Package | Version tested | Notes |
|---------|---------------|-------|
| rpicam-apps | v1.10.1 | pre-installed |
| libcamera | v0.6.0+rpt20251202 | pre-installed |
| curl | — | pre-installed |
| sftp | — | pre-installed |
| flock | — | pre-installed |
| libimage-exiftool-perl | 13.25 | `sudo apt install -y libimage-exiftool-perl` |

---

## Repository Structure

```
oscars-phenocam/
├── README.md
├── LICENSE
├── .gitignore
└── software/
    ├── VERSION                    ← current software version
    ├── VERSIONS.txt               ← tested hardware/software versions
    ├── CHANGELOG.md               ← version history
    ├── ReadME.txt                 ← software architecture overview
    ├── bin/                       ← executable entrypoints (called by systemd)
    │   ├── phenocam-capture.sh
    │   ├── phenocam-upload.sh
    │   ├── phenocam-run.sh
    │   ├── phenocam-usb-attach.sh
    │   ├── phenocam-usb-detach.sh
    │   └── diag_*.sh
    ├── scripts/                   ← reusable logic modules
    │   ├── common.sh
    │   ├── config_read.sh
    │   ├── cycle.sh
    │   ├── capture_vis.sh
    │   ├── meta_build.sh
    │   ├── net_check.sh
    │   ├── storage_manager.sh
    │   ├── queue_manager.sh
    │   ├── upload_sftp.sh
    │   ├── upload_ftp.sh
    │   └── uploader_daemon.sh
    ├── config/                    ← configuration file examples
    │   ├── settings_example.txt
    │   ├── server_example.txt
    │   ├── ftp_credentials.txt    ← placeholder (replace on RPi — never commit real credentials)
    │   └── ftp_credentials_example.txt
    └── systemd/                   ← systemd units and udev rules
        ├── phenocam-capture.service
        ├── phenocam-capture.timer
        ├── phenocam-upload.service
        ├── phenocam-upload.timer
        ├── phenocam-init.service
        ├── run-phenocam.mount
        └── 99-phenocam-usb.rules
```

---

## Quick Installation

> **Full step-by-step instructions** with technical explanations are in the
> installation guide (will be published in the Releases).

### Prerequisites

- Raspberry Pi 3B+ with **Raspberry Pi OS 64-bit Lite** (Debian 13 trixie, 2025-12-04)
  flashed using **Raspberry Pi Imager v2.0.6**
- Camera Module 3 connected to the CSI port
- Active Ethernet connection
- Any user with sudo privileges (the script is independent of the username)

### One-command installation

From the RPi terminal, run:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/main/install.sh | bash
```

This single command will:
1. Check OS, architecture and network connectivity
2. Install `git` and `exiftool` at pinned versions (`13.25+dfsg-1`) and freeze them
3. Clone this repository to `/opt/oscars-phenocam`
4. Verify all expected files are present
5. Enable the camera interface (non-interactive)
6. Deploy scripts to `/usr/local/lib/phenocam/`
7. Create configuration file templates in `/etc/phenocam/`
8. Generate an SSH key pair for SFTP and display the public key
9. Install and enable systemd units and udev rules
10. Run a first capture + upload cycle as a health check
11. Print **Installation complete** with status and next steps

### After installation

Data transfer supports two upload protocols — FTP and SFTP. SFTP is recommended for security (SSH key authentication, no password transmitted over the network).

For **both protocols**, edit the station settings first:

```bash
# 1. Set your station name and parameters
sudo nano /etc/phenocam/settings.txt        # edit SITENAME (line 1) at minimum
```

For **FTP** — edit credentials:
```bash
# 2. Set FTP server credentials
sudo nano /etc/phenocam/ftp_credentials.txt  # 5 lines: host, port, path, user, password
```

> If the camera was just enabled for the first time, a reboot is required:
> `sudo reboot`

For **SFTP** see the [SFTP Setup](#sftp-setup) section below.

### USB drive requirement

When USB drives are used for spillover storage, they must be **formatted as FAT32**.

---

## Configuration

The main configuration file is `/etc/phenocam/settings.txt` (13 positional fields):

| Field | Default | Description |
|-------|---------|-------------|
| SITENAME | — | Unique station identifier (used in filenames and upload paths) |
| UTC_OFFSET | +1 | UTC offset (e.g. +1 for CET) |
| TZ_LABEL | Europe/Rome | Full timezone name |
| START_HOUR | 7 | First capture hour (0–23) |
| END_HOUR | 19 | Last capture hour (0–23) |
| INTERVAL_MIN | 30 | Interval between captures (minutes) |
| IFACE | eth0 | Network interface for metadata (empty = auto-detect) |
| SFTP_USER | phenocam | SFTP username on remote server |
| NET_MODE | auto | auto \| ethernet \| wifi |
| RAM_MIN_FREE_MB | 20 | RAMDISK free space threshold before spillover (MB) |
| SD_MAX_USED_PCT | 80 | SD usage threshold; captures stop if exceeded (%) |
| USB_MOUNT_BASES | /media:/mnt | Colon-separated paths to scan for USB mounts |
| USB_MAX_USED_PCT | 90 | USB usage threshold; spills to SD if exceeded (%) |

---

## Output File Naming

```
SITENAME_hostname_YYYY_MM_DD_HHMMSS.jpg
SITENAME_hostname_YYYY_MM_DD_HHMMSS.meta
```

Files are uploaded to:
```
FTP_REMOTE_BASE / SITENAME / YYYY_MM_DD / filename.jpg
FTP_REMOTE_BASE / SITENAME / YYYY_MM_DD / filename.meta
```

---

## FTP Upload Setup

Edit `/etc/phenocam/ftp_credentials.txt` with your server details
(5 lines, one value per line, no comments):

```
FTP_HOST        ← IP address or hostname of the FTP server
FTP_PORT        ← port number (standard: 21)
FTP_REMOTE_BASE ← base path on server (must already exist)
FTP_USER        ← FTP username
FTP_PASS        ← FTP password
```

Files are uploaded to: `FTP_REMOTE_BASE / SITENAME / YYYY_MM_DD / filename`

> ⚠️ Never commit `ftp_credentials.txt` to any repository — it contains plain-text credentials.
> The `.gitignore` in this repository already excludes it.

---

## SFTP Setup

The installation script automatically generates an ed25519 SSH key pair at
`/etc/phenocam/keys/phenocam_key`. To view the public key and prerequisites status:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

**Never share** the private key (`phenocam_key` without `.pub`).

### Full SFTP configuration (once server is available)

**Step 1 — Send the public key to the server administrator**

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
# Copy the public key shown in the output and send it to the server admin
```

**Step 2 — Add the server hostname to server.txt**

```bash
sudo nano /etc/phenocam/server.txt
# Add one line: the hostname or IP of the SFTP server
# e.g.: phenocam.example.org
```

**Step 3 — Add the server fingerprint to known_hosts**

```bash
sudo ssh-keyscan -H <hostname_or_ip> >> /etc/phenocam/known_hosts
```

**Step 4 — Set the SFTP username in settings.txt**

```bash
sudo nano /etc/phenocam/settings.txt
# Edit line 8 (SFTP_USER) with the username provided by the server admin
```

**Step 5 — Set the remote directory in upload_sftp.sh**

```bash
sudo nano /usr/local/lib/phenocam/scripts/upload_sftp.sh
# Find: local remote_dir="TBD_REMOTE_DIR"
# Replace with the actual remote path agreed with the server admin
```

**Upload method selection** (automatic, based on which files are configured):

| server.txt | ftp_credentials.txt | Behaviour |
|-----------|-------------------|-----------|
| empty | empty | Warning — no upload configured |
| has content | empty | SFTP only |
| empty | has content | FTP only |
| has content | has content | Both SFTP and FTP |

---

## Diagnostics

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh   # list available cameras
sudo /usr/local/lib/phenocam/bin/diag_net.sh       # network interfaces and routes
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh   # RAMDISK status and usage
sudo /usr/local/lib/phenocam/bin/diag_upload.sh    # upload prerequisites + SSH public key
sudo cat /var/log/phenocam/phenocam.log | tail -20 # last 20 log lines
```

---

## Project Context

This software is developed within the **OSCARS** (Open Science Clusters' Action
for Research & Society) project, funded by the European Commission (grant 101129751).

- **Project page:** https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system
- **Project poster (Zenodo):** https://doi.org/10.5281/zenodo.18800314
- **Author:** Luca Cerato — Terrasystem s.r.l.
- **Project leader:** Dario Papale — Università degli Studi della Tuscia
- **Team:** Bert Gielen (University of Antwerp), Koen Hufkens (BlueGreen Labs)

---

## License

This software is released under the [MIT License](LICENSE).

---

## Contributing

This project is currently in active development. Issues and pull requests
are welcome once the repository is made public.
