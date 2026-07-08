# PhenoCam Changelog

All significant changes to this project are documented in this file.
Format: [Semantic Versioning](https://semver.org/) — MAJOR.MINOR.PATCH

---

## [1.4.0] — 2026-07-07

### Fixed after Zero 2 W validation (2026-07-08)
- `run-phenocam.mount`: RAMDISK ownership is now made persistent through uid/gid-aware mount options written by `phenocam-init-ramdisk.sh`.
- `phenocam-init.service`: removed fragile inline Bash RAMDISK calculation; runtime setup is delegated to `bin/phenocam-init-ramdisk.sh`.
- `phenocam-capture.service`: added `TimeoutStartSec=300` because Zero 2W captures can legitimately exceed 30 seconds end-to-end.
- `capture_vis.sh`: added headless `-n` capture mode and a wider GNU `timeout` guard. `CAPTURE_TIMEOUT` remains the rpicam warm-up time, not the OS guard.
- `install.sh`: fixed board auto-detection write to settings line 21; no literal `${DETECTED_BOARD:-unknown}` is written anymore.
- `install.sh`: production timers are not started by default until settings and upload credentials are configured.
- `uploader_daemon.sh`: SFTP is enabled only when `server.txt` has effective non-comment content.
- `uploader_daemon.sh`: FTP is enabled only when `ftp_credentials.txt` has five effective credential fields.
- `uploader_daemon.sh`: if both SFTP and FTP are configured, local files are removed only after all configured targets succeed.
- `upload_ftp.sh`: FTP port is fully configurable; FTP on port 22 remains `ftp://host:22/...` and is not converted to SFTP.

### Documentation
- Added `README.md` and structured docs under `software/docs/` for clean install, configuration, operations, and v1.4.0 development notes.


### Added
- Multi-hardware support via `settings.txt` configuration (no separate branches):
  - `BOARD` (field 21): `rpi3b+` | `rpizero2w` | `unknown`
    Auto-detected from `/proc/cpuinfo` by `install.sh` at install time.
  - `CAMERA_MODEL` (field 22): `imx708` (Camera Module 3) | `imx708_noir` (V3 NoIR)
    Set manually after installation.
  - `CAPTURE_TIMEOUT` (field 23): rpicam-still timeout in ms (default 30000).
    Same value is safe on both boards; has no effect on image quality.

- `capture_vis.sh`: added `--timeout` flag using `CAPTURE_TIMEOUT` variable.
  Prevents the ISP from being cut off on slower boards (Zero 2W) before
  exposure and white balance have stabilised.

- Dynamic RAMDISK sizing in `phenocam-init.service`:
  - Calculates 20% of total RAM at boot, with a minimum of 50 MB.
  - Writes the result into `run-phenocam.mount` before (re)starting the mount.
  - RPi 3B+ (1024 MB): ~204 MB RAMDISK
  - RPi Zero 2W (512 MB): ~102 MB RAMDISK
  - Replaces the previous hardcoded 200 MB value.

- `install.sh`: auto-detects board model from `/proc/cpuinfo` and writes
  the `BOARD` field into `settings.txt` (line 21) automatically.

### Changed
- `config_read.sh`: added fields 21 (`BOARD`), 22 (`CAMERA_MODEL`),
  23 (`CAPTURE_TIMEOUT`).
- `VERSIONS.txt`: documents all four supported hardware combinations
  (2 boards × 2 cameras). RPi Zero 2W kernel to be filled after first
  verified installation.

---

## [1.3.0] — 2026-04-01

### Added
- Site metadata fields in `settings.txt` (fields 15–20):
  `SITE_LAT`, `SITE_LON`, `SITE_ELEV_M`, `SITE_START_DATE`,
  `SITE_END_DATE`, `SITE_NIMAGE` — all default to `nd` (not defined).
- `REMOTE_LAYOUT` field (field 14): `general` | `icos` — selects the
  remote directory structure for upload (PhenoCam general network or
  ICOS Europe network).
- `logrotate` configuration: `config/phenocam.logrotate` — weekly rotation,
  4 weeks history, compression, copytruncate (no service restart required).
  Installed to `/etc/logrotate.d/phenocam` by `install.sh`.
- `install.sh`: installs logrotate configuration automatically.
- SSH key permissions aligned for phenocam user (600 private, 644 public).
- SFTP setup instructions added to the final report in `install.sh`.

### Changed
- `settings.txt` expanded from 13 to 20 fields (backward compatible —
  missing fields default gracefully).

---

## [1.2.2] — 2026-03-19

### Bugfix
- `meta_build.sh`: removed erroneous `_fixed` suffix on the `ev` line
  inside the `[capture_params_fixed]` section.

---

## [1.2.1] — 2026-03-19

### Bugfix
- `phenocam-init.service`: `phenocam-run.sh` is now executed via
  `runuser -u phenocam` instead of root. This ensures all files created
  at boot (capture.lock, upload.lock, phenocam.log) are immediately owned
  by `phenocam:phenocam`, eliminating the need for subsequent chown calls.
  Fixes: 'Permission denied' on capture.lock and phenocam.log after
  a fresh installation.

---

## [1.2.0] — 2026-03-18

### Added
- USB hot-plug support via udev:
  - `bin/phenocam-usb-attach.sh`: on plug-in, creates the queue directory
    and logs the event
  - `bin/phenocam-usb-detach.sh`: on removal, performs lazy unmount,
    cleans up orphan .tmp files, logs the event
  - `systemd/99-phenocam-usb.rules`: udev rule (requires FAT32,
    install in /etc/udev/rules.d/)
- Configurable USB usage threshold: new field 13 in settings.txt
  `USB_MAX_USED_PCT` (default 90%). If USB exceeds the threshold,
  the system spills over to SD instead of blocking.
- Orphan .tmp file cleanup: new function `cleanup_tmp_orphans()`
  in storage_manager.sh
- New helper function `usb_is_mounted()` in storage_manager.sh

### Changed
- `config_read.sh`: added field 13 `USB_MAX_USED_PCT`
- `queue_manager.sh`: checks USB threshold before using it as spillover
- `settings_example.txt`: added field 13 with comment

---

## [1.1.0] — 2026-03-18

### Changed
- File naming now uses underscores throughout:
  `mysite_phenocam01_2026_03_18_133005.jpg`
  (hostname always lowercase, date with underscores instead of hyphens)
- Enriched metadata: added `[capture_params_fixed]` section with all fixed
  capture parameters (width, height, awb, gain, sharpness, contrast,
  brightness, saturation, denoise, ev, lens_position, quality)
- exiftool now uses `-a -u -g1` to extract all available tags including
  non-standard Camera Module 3 tags
- Automatic capture+upload cycle on first boot: `phenocam-init.service`
  now runs `phenocam-run.sh` after the RAMDISK chown
- `phenocam-init.service` now waits for `network-online.target` before
  running the initial cycle

---

## [1.0.0] — 2026-03-18

First stable release. Tested and verified on Phenocam01, Phenocam02, Phenocam03.

### Features
- Periodic image acquisition with rpicam-still (Camera Module 3)
- Metadata file (.meta) with EXIF data + network info (IP, MAC, interface)
- 3-level queue: RAMDISK (200MB tmpfs) → USB → SD card
- FTP upload via curl (user+password, passive mode, date-based subfolders)
- SFTP upload with ed25519 SSH key (infrastructure ready, server TBD)
- systemd timers: capture at :00 and :30 every hour, upload every 9 minutes
- Automatic startup at boot via systemd
- systemd security hardening (NoNewPrivileges, ProtectSystem,
  MemoryDenyWriteExecute)
- Diagnostic scripts: diag_camera.sh, diag_net.sh, diag_ramdisk.sh,
  diag_upload.sh

### Bugs fixed (compared to development versions)
- Windows CRLF in scripts caused "invalid option name: pipefail"
- `$0` instead of `${BASH_SOURCE[0]}` in cycle.sh caused
  "No such file or directory"
- `/etc/phenocam/` with root group prevented phenocam from reading files
- phenocam user not in video group caused "Permission denied" on /dev/media*
- Missing `source upload_ftp.sh` in phenocam-upload.sh caused
  "command not found"
- `chown /run/phenocam` did not persist across reboots —
  fixed with phenocam-init.service
- Merged lines in settings.txt (e.g. `80/media:/mnt`) caused
  "unbound variable"
- Trailing space in ftp_credentials.txt caused "URL bad/illegal format"
- Orphan files in staging were never removed — added automatic cleanup

---
