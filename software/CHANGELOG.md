# Changelog

Code changes between OSCARS-PHENOCAM versions `1.3.0` and `dev/v1.7.0`.

## [dev/v1.7.0]

### Changed

* `UTC_OFFSET` configures a fixed station timezone without daylight-saving-time changes.
* `TZ` and `TZ_LABEL` are generated from `UTC_OFFSET`.
* The default network interface is `auto`.
* An explicit `IFACE` is used when the interface exists.
* With `NET_MODE=auto`, network selection prefers the interface used by the default route and then the first non-loopback interface with a global IPv4 address.
* Metadata uses the same interface-resolution functions as the upload subsystem.
* `phenocam-capture.timer` runs at minutes `00` and `30` of every hour in UTC.
* The installer no longer derives the network interface from the Raspberry Pi model.

## [dev/v1.6.0]

### Added

* `phenocam-startup-cycle.sh`, which runs one capture followed by one upload request.
* `phenocam-startup-cycle.service`.
* `phenocam-startup-cycle.timer`, scheduled two minutes after boot.
* Runtime version file at `/usr/local/lib/phenocam/VERSION`.
* Runtime installation information at `/usr/local/lib/phenocam/BUILD_INFO`.
* A `[phenocam]` metadata section containing software name, version, branch, commit and installation timestamp.

### Changed

* The installer enables or disables the startup-cycle timer together with the capture and upload timers.

## [1.5.0]

### Added

* `system_health.sh` for collecting:

  * SoC temperature;
  * ARM clock frequency;
  * current throttling and undervoltage flags;
  * throttling and undervoltage events recorded since boot.
* A `[system_health]` section in each generated metadata file.
* `diag_system_health.sh` for displaying the collected system-health values.

## [1.4.0]

### Added

* `phenocam-init-ramdisk.sh` for preparing `/run/phenocam`.
* RAM-disk sizing equal to 20% of total system memory, with a minimum of 50 MB.
* RAM-disk ownership based on the numeric UID and GID of the `phenocam` user.
* Protection against restarting an active RAM-disk mount when queued `.jpg` or `.meta` files are present.
* An operating-system timeout around the camera command.
* `BOARD`, `CAMERA_MODEL` and `CAPTURE_TIMEOUT` fields in the settings parser.

### Changed

* Camera capture runs without a preview window.
* `CAPTURE_TIMEOUT` is passed to the camera command and defaults to `30000` milliseconds.
* `BOARD` and `CAMERA_MODEL` are exported but are not consumed by the runtime capture scripts.
* Carriage-return characters are removed when reading settings and FTP credentials.
* FTP ports must contain only digits.
* FTP transfers use passive mode, connection and transfer timeouts, and retries.
* SFTP and FTP activation depends on effective configuration content.
* When both protocols are enabled, a local image and metadata pair is removed only if both upload attempts succeed.
* Capture and upload services require the initialization service and RAM-disk mount.
* The initialization service prepares the RAM disk and does not run a capture-and-upload cycle.

## [1.3.1]

### Changed

* The installer creates an empty `ftp_credentials.txt` instead of inserting placeholder credentials.
* SFTP is enabled only when `server.txt` contains a non-empty, non-comment line.

## [1.3.0]

Initial comparison baseline for this changelog.

