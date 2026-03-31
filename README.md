# oscars-phenocam

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.3.0-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System — PhenoCam Software**

Raspberry Pi-based phenological camera system for automated image acquisition and upload.  
Part of the [OSCARS](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system) Open Science project (EU grant 101129751).

---

## Overview

This software turns a Raspberry Pi 3B+ with a Camera Module 3 into an autonomous phenological camera station. It captures images at scheduled intervals, builds structured metadata sidecar files, and uploads image/metadata pairs to one or more remote destinations.

The current `dev/v1.3.0` branch is focused on:

- keeping the original OSCARS workflow stable and flexible
- improving compatibility with external phenology data workflows
- making output files easier to organize and analyze
- preserving support for user-defined FTP/SFTP destinations
- enabling layout compatibility with ICOS / NetCam-style remote ingestion where required

---

## Key Features

- Scheduled captures at `:00` and `:30` of every hour within a configurable time window.
- Structured per-image `.meta` files with:
  - `[system]`
  - `[capture_params_fixed]`
  - `[exif]`
- Sidecar metadata enriched with site-level fields useful for later analysis
- Standardized image naming:
  - `SITENAME_YYYY_MM_DD_HHMMSS.jpg`
  - `SITENAME_YYYY_MM_DD_HHMMSS.meta`
- 3-level queue:
  - RAMDISK → USB drive → SD card
- Optional upload via:
  - FTP (single configured server)
  - SFTP (one or more configured servers)
- Two selectable remote directory layouts:
  - `general` → `sitename/YYYY/MM/`
  - `icos` → `data/sitename/`
- Automatic first-boot health check
- USB hot-plug support
- systemd hardening and diagnostics

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

All dependencies are available via `apt` on Raspberry Pi OS Lite.

| Package | Version tested | Notes |
|---------|---------------|-------|
| rpicam-apps | v1.10.1 | pre-installed |
| libcamera | v0.6.0+rpt20251202 | pre-installed |
| curl | — | pre-installed |
| sftp | — | pre-installed |
| flock | — | pre-installed |
| libimage-exiftool-perl | 13.25 | installed by `install.sh` |

---

## Repository Structure

```text
oscars-phenocam/
├── README.md
├── LICENSE
├── .gitignore
└── software/
    ├── VERSION
    ├── VERSIONS.txt
    ├── CHANGELOG.md
    ├── ReadME.txt
    ├── bin/
    │   ├── phenocam-capture.sh
    │   ├── phenocam-upload.sh
    │   ├── phenocam-run.sh
    │   ├── phenocam-usb-attach.sh
    │   ├── phenocam-usb-detach.sh
    │   └── diag_*.sh
    ├── scripts/
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
    ├── config/
    │   ├── settings_example.txt
    │   ├── server_example.txt
    │   ├── ftp_credentials.txt
    │   └── ftp_credentials_example.txt
    └── systemd/
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

> **Branch note**
> This repository currently provides two installation tracks:
> - `main` for the stable installation path
> - `dev/v1.3.0` for testing the current development version
>
> Use the development installer only if you explicitly want to test the latest branch-specific changes before they are merged into `main`.

### Prerequisites

- Raspberry Pi 3B+ with **Raspberry Pi OS 64-bit Lite** (Debian 13 trixie, 2025-12-04) flashed using **Raspberry Pi Imager v2.0.6**
- Camera Module 3 connected to the CSI port
- Active Ethernet connection
- Any user with sudo privileges

### Stable installation (`main`)

From the RPi terminal, run:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/main/install.sh | bash
```

### Development installation (`dev/v1.3.0`)

From the RPi terminal, run:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/dev/v1.3.0/install.sh | bash
```

This single command will:

1. Check OS, architecture and network connectivity
2. Install `git` and `exiftool` at pinned versions and freeze `exiftool`
3. Clone this repository to `/opt/oscars-phenocam`
4. Verify all expected files are present
5. Enable the camera interface
6. Deploy scripts to `/usr/local/lib/phenocam/`
7. Create configuration templates in `/etc/phenocam/`
8. Generate an SSH key pair for SFTP and display the public key
9. Install and enable systemd units and udev rules
10. Run a first capture + upload cycle as a health check
11. Print installation status and next steps

### After installation

Data transfer supports two optional upload protocols:

- **FTP**
- **SFTP**

You may configure:
- only FTP
- only SFTP
- both

SFTP is recommended where SSH key authentication is available.

For both protocols, edit station settings first:

```bash
sudo nano /etc/phenocam/settings.txt
```

For FTP, edit credentials:

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

For SFTP, see the [SFTP Setup](#sftp-setup) section below.

> If the camera was just enabled for the first time, a reboot may be required:
> `sudo reboot`

### USB Drive Requirement

When USB drives are used for spillover storage, they must be formatted as **FAT32**.

---

## Configuration

The main configuration file is:

```text
/etc/phenocam/settings.txt
```

This file uses a **positional format**: one value per line.  
Do **not** remove lines or change their order.  
If a value is not yet available, use `nd`.

### settings.txt Fields (20 positional fields)

| Pos. | Field | Default | Description |
|------|-------|---------|-------------|
| 1 | SITENAME | — | Unique station identifier used in filenames and upload paths |
| 2 | UTC_OFFSET | +1 | UTC offset (e.g. `+1`, `+2`, `0`, `-5`) |
| 3 | TZ_LABEL | Europe/Rome | Full timezone name |
| 4 | START_HOUR | 6 | First capture hour (0–23) |
| 5 | END_HOUR | 22 | End hour of capture window (0–23) |
| 6 | INTERVAL_MIN | 30 | Interval between captures in minutes |
| 7 | IFACE | eth0 | Network interface for metadata (`empty = auto-detect`) |
| 8 | SFTP_USER | phenocam | SFTP username on remote server |
| 9 | NET_MODE | auto | `auto | ethernet | wifi` |
| 10 | RAM_MIN_FREE_MB | 20 | RAMDISK free-space threshold before spillover |
| 11 | SD_MAX_USED_PCT | 80 | SD usage threshold; captures stop if exceeded |
| 12 | USB_MOUNT_BASES | /media:/mnt | Colon-separated paths to scan for mounted USB drives |
| 13 | USB_MAX_USED_PCT | 90 | USB usage threshold; spills to SD if exceeded |
| 14 | REMOTE_LAYOUT | general | `general` or `icos` |
| 15 | SITE_LAT | nd | Site latitude in decimal degrees |
| 16 | SITE_LON | nd | Site longitude in decimal degrees |
| 17 | SITE_ELEV_M | nd | Site elevation above sea level in meters |
| 18 | SITE_START_DATE | nd | Site start date in `YYYY-MM-DD` format |
| 19 | SITE_END_DATE | nd | Site end date in `YYYY-MM-DD` format |
| 20 | SITE_NIMAGE | nd | Image count or analysis-side placeholder |

### Notes on Optional Site Metadata

The fields:

- `SITE_LAT`
- `SITE_LON`
- `SITE_ELEV_M`
- `SITE_START_DATE`
- `SITE_END_DATE`
- `SITE_NIMAGE`

are always present in `settings.txt` and are written into every `.meta` file.  
If a value is not yet known, keep it as:

```text
nd
```

This ensures that all generated `.meta` files share the same structure.

---

## Output File Naming

Image and metadata files are generated as:

```text
SITENAME_YYYY_MM_DD_HHMMSS.jpg
SITENAME_YYYY_MM_DD_HHMMSS.meta
```

The hostname is **not** included in the filename.

---

## Remote Upload Layouts

The upload path depends on `REMOTE_LAYOUT`.

### `general`

Used for general-purpose organization and easier downstream processing:

```text
sitename/YYYY/MM/
```

Examples:

```text
mysitepheno04/2026/03/mysitepheno04_2026_03_24_103002.jpg
mysitepheno04/2026/03/mysitepheno04_2026_03_24_103002.meta
```

### `icos`

Used for compatibility with ICOS / NetCam-style flat site layout:

```text
data/sitename/
```

Examples:

```text
data/mysitepheno04/mysitepheno04_2026_03_24_103002.jpg
data/mysitepheno04/mysitepheno04_2026_03_24_103002.meta
```

---

## Uploaded Files

The system uploads only the following files:

- `.jpg`
- `.meta`

No additional site-level configuration files are uploaded by the normal queue workflow.

---

## Metadata Sidecar Files (`.meta`)

For each image, the system generates a `.meta` sidecar file with three sections:

```text
[system]
[capture_params_fixed]
[exif]
```

### `[system]`

This section contains station and acquisition context, including:

- `sitename`
- `hostname`
- `timestamp`
- `datetime_original`
- `tz`
- `utc_offset`
- `network`
- `lat`
- `lon`
- `elev`
- `start_date`
- `end_date`
- `nimage`
- `iface`
- `ip`
- `mac`
- `image_file`

### `[capture_params_fixed]`

This section contains fixed capture settings used by the acquisition pipeline, such as:

- `width`
- `height`
- `awb`
- `gain`
- `sharpness`
- `contrast`
- `brightness`
- `saturation`
- `denoise`
- `ev`
- `lens_position`
- `quality`

### `[exif]`

This section contains the EXIF metadata extracted from the JPEG using `exiftool`.

### Notes on analysis-oriented metadata

The `.meta` sidecar now includes site-level placeholders useful for later analysis workflows:

- `lat`
- `lon`
- `elev`
- `start_date`
- `end_date`
- `nimage`

The field:

```text
datetime_original="..."
```

is included as a NetCam-style alias of the acquisition timestamp.

The field:

```text
network=general
```

or

```text
network=icos
```

records the currently selected remote layout / compatibility mode.

---

## FTP Upload Setup

Edit:

```text
/etc/phenocam/ftp_credentials.txt
```

with your server details, one value per line:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

### FTP path behavior

- with `REMOTE_LAYOUT=general`:

```text
FTP_REMOTE_BASE/sitename/YYYY/MM/
```

- with `REMOTE_LAYOUT=icos`:

```text
FTP_REMOTE_BASE/data/sitename/
```

> If you use `REMOTE_LAYOUT=icos`, `FTP_REMOTE_BASE` should be the root **above** `data`, not `/data` itself, to avoid producing `/data/data/...`.

> Never commit `ftp_credentials.txt` to any repository. It contains plain-text credentials.

---

## SFTP Setup

The installation script automatically generates an ed25519 SSH key pair at:

```text
/etc/phenocam/keys/phenocam_key
```

To view upload prerequisites and the public key:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

**Never share the private key** (`phenocam_key` without `.pub`).

### Full SFTP Configuration

#### 1. Send the public key to the server administrator

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

#### 2. Add one or more SFTP servers

```bash
sudo nano /etc/phenocam/server.txt
```

Add one hostname or IP per line, for example:

```text
phenocam.example.org
sftp.example.net
```

#### 3. Add the server fingerprint(s)

```bash
sudo ssh-keyscan -H <hostname_or_ip> >> /etc/phenocam/known_hosts
```

#### 4. Set the SFTP username

```bash
sudo nano /etc/phenocam/settings.txt
```

Edit line 8 (`SFTP_USER`) with the username provided by the server administrator.

#### 5. Set the remote layout

Edit line 14 of `settings.txt`:

```text
general
```

or

```text
icos
```

### SFTP path behavior

- with `REMOTE_LAYOUT=general`:

```text
sitename/YYYY/MM/
```

- with `REMOTE_LAYOUT=icos`:

```text
data/sitename/
```

---

## Upload Method Selection

Protocol activation is automatic and depends on which configuration files are populated.

| server.txt | ftp_credentials.txt | Behaviour |
|-----------|---------------------|-----------|
| empty | empty | Warning — no upload configured |
| has content | empty | SFTP only |
| empty | has content | FTP only |
| has content | has content | Both enabled |

### Current operational note

When both protocols are configured, the current upload pipeline is queue-based and protocol activation is automatic. The queue is retained when uploads fail and files are retried in later cycles.

### Supported destination flexibility

The software can be configured to upload to:

- user-defined FTP destinations
- one or more user-defined SFTP destinations

Where agreements and server-side configuration exist, the same `.jpg + .meta` workflow may also be adapted for compatibility with:

- ICOS-oriented ingestion paths
- PhenoCam / NetCam-style remote organization

---

## Diagnostics

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
sudo /usr/local/lib/phenocam/bin/diag_net.sh
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
sudo cat /var/log/phenocam/phenocam.log | tail -20
```

---

## Development Notes for `dev/v1.3.0`

The current development branch includes structural changes aimed at:

1. improving metadata consistency
2. simplifying file naming
3. supporting multiple remote directory layouts
4. preserving flexibility for custom upload destinations
5. making per-image metadata more useful for downstream analysis workflows

At this stage, the project intentionally keeps the normal acquisition and upload workflow centered on:

- one JPEG image
- one `.meta` sidecar file

for each acquisition cycle.

---

## Planned / Future Work

The following topics remain open for future development:

- upload-time randomization with collision avoidance relative to capture cycles
- optional embedded EXIF enrichment beyond the current sidecar-based metadata strategy
- further documentation for ICOS / PhenoCam-specific deployment agreements
- possible export helpers for analysis-side metadata formats

---

## Project Context

This software is developed within the **OSCARS** (Open Science Clusters' Action for Research & Society) project, funded by the European Commission (grant 101129751).

- **Project page:** https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system
- **Project poster (Zenodo):** https://doi.org/10.5281/zenodo.18800314
- **Author:** Luca Cerato — Terrasystem s.r.l.
- **Project leader:** Dario Papale — Università degli Studi della Tuscia
- **Team:** Bert Gielen (University of Antwerp), Koen Hufkens (BlueGreen Labs)

---

## License

This software is released under the [BSD 3-Clause License](LICENSE).

---

## Contributing

This project is currently in active development. Issues and pull requests are welcome.
