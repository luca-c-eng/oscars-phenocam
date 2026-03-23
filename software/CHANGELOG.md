# PhenoCam Changelog

All significant changes to this project are documented in this file.
Format: [Semantic Versioning](https://semver.org/) — MAJOR.MINOR.PATCH

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

First stable release. Tested and verified on Phenocam01, Phenocam02,
Phenocam03.

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

### Components
- `bin/`: phenocam-capture.sh, phenocam-upload.sh, phenocam-run.sh,
  diag_*.sh, phenocam-usb-attach.sh, phenocam-usb-detach.sh
- `scripts/`: common.sh, cycle.sh, config_read.sh, capture_vis.sh,
  meta_build.sh, net_check.sh, storage_manager.sh, queue_manager.sh,
  upload_sftp.sh, upload_ftp.sh, uploader_daemon.sh
- `systemd/`: phenocam-capture.service/.timer, phenocam-upload.service/.timer,
  phenocam-init.service, run-phenocam.mount, 99-phenocam-usb.rules
- `config/`: settings_example.txt, server_example.txt,
  ftp_credentials.txt (placeholder), ftp_credentials_example.txt

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

## [Unreleased]

### TODO (eventually - to evaluete)
- PhenoCam Network directory structure compatibility (sitename/YYYY/MM/)
- Clarify .meta format requirements with PhenoCam Network
- Manual stop/start commands (phenocam-stop, phenocam-start)
