# Changelog

All notable, code-verifiable changes to OSCARS-PHENOCAM are documented in this file.

## [dev/v1.7.0]

### Changed

* Station time is derived from `UTC_OFFSET` and uses a fixed UTC offset without daylight-saving-time changes.
* The default network interface is `auto` instead of a board-specific interface.
* Automatic network selection uses the interface associated with the default route, with a fallback to the first non-loopback interface having a global IPv4 address.
* Metadata collection uses the same network-interface resolution logic as the uploader.
* The capture timer explicitly runs at minutes `00` and `30` of every hour in UTC.
* The installer checks protected configuration files through `sudo` and obtains the installed commit through `sudo git`.
* The default `settings.txt` template uses `UTC+1` as its timezone label and `auto` as its interface.

## [dev/v1.6.0]

### Added

* Startup test cycle implemented by:

  * `phenocam-startup-cycle.sh`
  * `phenocam-startup-cycle.service`
  * `phenocam-startup-cycle.timer`
* The startup timer runs once, two minutes after boot.
* The startup cycle performs one capture followed by one upload attempt.
* Runtime version information is installed in `/usr/local/lib/phenocam/VERSION`.
* Installation information is written to `/usr/local/lib/phenocam/BUILD_INFO`.
* Metadata includes a `[phenocam]` section containing software version, branch, commit and installation timestamp.

### Changed

* The installer enables the startup-cycle timer together with the regular capture and upload timers.
* `PHENOCAM_DISABLE_TIMERS=1` disables all three timers.

## [1.5.0]

### Added

* Raspberry Pi system-health collection through `system_health.sh`.
* The following values are collected:

  * SoC temperature;
  * ARM clock frequency;
  * current undervoltage and throttling flags;
  * throttling and undervoltage events recorded since boot.
* Captured-image metadata includes a `[system_health]` section.
* `diag_system_health.sh` provides direct command-line access to the collected health values.

## [1.4.0]

### Added

* Dynamic RAM-backed storage initialization through `phenocam-init-ramdisk.sh`.
* RAM-disk size is calculated as 20% of total memory, with a minimum of 50 MB.
* The RAM-disk mount uses the numeric user and group identifiers of the `phenocam` account.
* Existing queued image or metadata files prevent an automatic RAM-disk restart.
* Camera capture is protected by an operating-system timeout.
* `CAPTURE_TIMEOUT` controls the camera warm-up timeout and defaults to `30000` milliseconds.
* `BOARD`, `CAMERA_MODEL` and `CAPTURE_TIMEOUT` are read and exported from `settings.txt`.

### Changed

* Only `CAPTURE_TIMEOUT` is consumed by the capture implementation; `CAMERA_MODEL` is not used to select capture behaviour.
* Camera capture runs without a preview window.
* FTP configuration requires a numeric port.
* FTP transfers use passive mode, connection and transfer timeouts, and retry parameters.
* SFTP and FTP activation is based on effective configuration content rather than file size alone.
* When both upload protocols are enabled, each pair is removed only after both upload attempts succeed.
* Capture and upload services require the initialization service and RAM-disk mount.
* The initialization service prepares the RAM disk and no longer launches a capture-and-upload cycle.
* Production timers are enabled for the next boot but are not started immediately by the installer.
* Existing configuration files are preserved during installation.

## [1.3.1]

### Changed

* The installer creates an empty FTP credentials file instead of placeholder credentials.
* Blank and comment-only lines are excluded while reading `settings.txt`.
* SFTP is enabled only when `server.txt` contains at least one non-empty, non-comment line.
* Comment-only SFTP configuration no longer activates an upload attempt.

## [1.3.0]

### Added

* `REMOTE_LAYOUT` configuration with `general` and `icos` remote directory layouts.
* Station metadata fields for latitude, longitude, elevation, monitoring start date, monitoring end date and image count.
* A `[system]` metadata section.
* `datetime_original` as an alias of the acquisition timestamp.
* Log rotation for `/var/log/phenocam/phenocam.log`:

  * rotation at 1 MB;
  * seven retained archives;
  * compression of rotated logs.

### Changed

* Image names use `<SITENAME>_<timestamp>` and no longer include the hostname.
* FTP and SFTP remote paths are generated from `REMOTE_LAYOUT`.
* In `general` layout, files are grouped by station, year and month.
* In `icos` layout, files are placed below `data/<SITENAME>`.
* Local image and metadata pairs are retained until the last enabled upload protocol succeeds.
* SD-card usage is checked only when the queue must fall back from RAM or USB storage to the SD card.
* Capture-window hour values are converted explicitly to base-10 integers.

## [1.2.2]

This is the earliest tagged code snapshot used as the comparison baseline.
