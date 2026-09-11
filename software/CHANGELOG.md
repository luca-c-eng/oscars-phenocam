# Changelog

This file records notable OSCARS-PHENOCAM software changes reconstructed from the Git history and executable code.

Dates correspond to version-marker or installer-branch transitions. No Git tags are currently present in the repository.

Documentation-only changes are not included.

---

## `dev/v1.7.0` — 2026-08-26

### Added

* Fixed station-time configuration derived from `UTC_OFFSET`.
* Support for signed UTC offsets, including optional minute components.
* Shared network-interface resolution through `net_check.sh`.

### Changed

* Set the default network interface to `auto`.

* Removed the association between Raspberry Pi model and network-interface selection.

* Network selection now follows this priority:

  1. configured interface;
  2. configured Ethernet or Wi-Fi mode;
  3. interface selected by the default route;
  4. first non-loopback interface with a global IPv4 address.

* Metadata generation now uses the shared network resolver.

* Capture scheduling now explicitly uses UTC:

  ```ini
  OnCalendar=*-*-* *:00,30:00 UTC
  ```

* Updated installer repository and version references to `dev/v1.7.0`.

### Fixed

* Configuration-file existence checks now use `sudo test`.
* SSH-key existence checks now work with protected configuration directories.
* Installed Git commit detection now runs with the permissions required for `/opt/oscars-phenocam`.
* Corrected creation of the default `settings.txt`.

---

## `dev/v1.6.0` — 2026-07-10

### Added

* Startup capture-and-upload script.

* Dedicated startup-cycle `systemd` service.

* Timer that requests the startup cycle approximately two minutes after boot.

* Runtime `VERSION` installation.

* Runtime `BUILD_INFO` containing:

  * software name;
  * version;
  * branch;
  * Git commit;
  * installation timestamp.

* `[phenocam]` section in each `.meta` sidecar.

* Fallback metadata when `BUILD_INFO` is unavailable.

### Changed

* Installer timer management now includes the startup-cycle timer.
* Installation summary now reports system health and build-information commands.

---

## `dev/v1.5.0` — 2026-07-09

### Added

* Raspberry Pi system-health module.
* SoC temperature acquisition.
* ARM clock-frequency acquisition.
* Current and historical undervoltage and throttling decoding.
* `[system_health]` section in each `.meta` sidecar.
* `diag_system_health.sh` diagnostic command.
* Health scripts to the installer’s critical-file verification.

### Historical Note

The installer branch was changed to `dev/v1.5.0`, but `software/VERSION` remained at `1.4.0`. The version marker was subsequently changed directly to `1.6.0`.

---

## `1.4.0` — 2026-07-07

### Added

* Positional configuration records for:

  * `BOARD`;
  * `CAMERA_MODEL`;
  * `CAPTURE_TIMEOUT`.

* Camera warm-up timeout support.

* Operating-system timeout guard around the camera command.

* Dynamic RAM-disk initialization through `phenocam-init-ramdisk.sh`.

* RAM-disk sizing based on 20% of total memory, with a 50 MB minimum.

* Automatic Raspberry Pi board detection during installation.

### Changed

* Moved RAM-disk preparation from inline service logic to a dedicated script.
* Updated capture and upload service dependencies on initialization and the RAM mount.
* Increased service execution timeouts.
* Improved positional configuration parsing for comments, empty lines, and CRLF input.
* Improved effective FTP and SFTP configuration detection.
* Updated FTP credential parsing and validation.
* Changed local-pair deletion so it occurs only after every enabled upload protocol succeeds.
* Improved installer privilege checks, camera checks, timer setup, and deployment verification.

### Current Behaviour of New Fields

`BOARD` and `CAMERA_MODEL` are loaded and exported but do not alter runtime behaviour in the current code.

---

## `1.3.0` — 2026-03-30

### Added

* `REMOTE_LAYOUT` configuration with `general` and `icos` layouts.

* Site metadata fields:

  * latitude;
  * longitude;
  * elevation;
  * site start date;
  * site end date;
  * image value.

* `datetime_original` metadata alias.

* `network` metadata field containing the selected remote layout.

* Log rotation for `/var/log/phenocam/phenocam.log`.

* FTP and SFTP remote-directory creation for both supported layouts.

### Changed

* Simplified filenames by removing the hostname:

  ```text
  SITENAME_YYYY_MM_DD_HHMMSS
  ```

* Changed the general remote layout to:

  ```text
  SITENAME/YYYY/MM/
  ```

* Added the ICOS layout:

  ```text
  data/SITENAME/
  ```

* Changed SD-capacity evaluation so it is applied when SD fallback is required.

* Improved numeric handling of capture-window hours.

* Updated the capture schedule to minutes `00` and `30`.

* Updated SFTP-key ownership and `known_hosts` creation.

* Changed the project license to BSD 3-Clause.

---

## `1.2.2` — 2026-03-20

### Initial Release

* Automated visible-image acquisition.
* Per-image `.meta` sidecar generation.
* Scheduled capture and upload through `systemd`.
* RAM, USB, and SD storage queues.
* FTP and SFTP upload support.
* USB insertion and removal handlers.
* Camera, network, RAM-disk, and upload diagnostics.
* Automated installer and runtime deployment.

---

[Back to the project README](../README.md)
