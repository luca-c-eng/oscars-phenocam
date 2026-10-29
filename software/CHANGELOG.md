# Changelog

Changes from OSCARS-PHENOCAM version `1.3.0` through the current
`dev/v0.1.0` development line.

## [dev/v0.1.0]

### Added

* Direct ICOS Carbon Portal staging and production support using the standard authenticated two-step workflow.
* Daily, root-level, uncompressed Level-0 ZIP creation for the `etcPhenocamDaily` object specification.
* SHA-256 metadata packages containing the station, instrument and station-day acquisition interval.
* Immutable retry outbox, environment binding, upload receipts and manifest-verified source cleanup.
* `CP_ENVIRONMENT`, `CP_SUBMITTER_ID`, `CP_STATION_URI`, `CP_INSTRUMENT_URI`, `ICOS_FILENAME_SUFFIX` and `CAPTURE_MINUTE` as settings fields 29–34.
* A separate protected Carbon Portal credentials file.
* Persistent randomized capture/upload scheduling and a schedule-configuration helper.
* Automated tests for ICOS configuration, scheduling, daily packaging and the HTTP client.
* `PROVENANCE.md` recording the preserved v1.8.0 derivation point, contributor attribution and external Vision Edge integration.
* `CITATION.cff` containing software citation metadata.
* `IMAGE_WIDTH`, `IMAGE_HEIGHT` and `IMAGE_QUALITY` as optional settings fields 26, 27 and 28.
* Validation of the documented Camera Module 3 resolution profiles: `1536x864`, `2304x1296` and `4608x2592`.
* JPEG quality validation for integer values from `1` to `100`.
* Automated tests for capture defaults, supported profiles, quality boundaries and invalid values.
* Configuration and testing documentation for the new image-capture settings.

### Changed

* The runtime version marker and development-branch references now identify `dev/v0.1.0`.
* The default image resolution is `2304x1296`.
* Direct capture and metadata-generation fallbacks use the same `2304x1296` default.
* The initial JPEG quality default remains `100` pending comparative tests.
* New configuration files contain 34 positional fields and default to the ICOS staging environment.
* Existing 23-field, 25-field, 27-field and 28-field configurations are migrated to the 34-field ICOS layout with an interval-compatible persistent capture offset.
* The operational upload entry point is dedicated to ICOS and no longer selects FTP or SFTP destinations.
* `metadata` is the default Vision Edge mode and does not modify the JPEG.
* The optional image-blurring output provided by Vision Edge is not exposed by
  the ICOS workflow and is not included in final sidecars.
* Missed timer events are not replayed after downtime, and the startup
  capture/upload diagnostic is no longer scheduled automatically.
* JPEG/META queue publication now verifies cross-filesystem copies, preserves
  complete staging pairs for retry and prevents overwriting conflicting files.
* Daily packaging no longer applies an undocumented local ZIP-size limit;
  Carbon Portal validation remains authoritative.
* Uploaded source cleanup must remove and verify every manifest entry before
  the receipt and immutable outbox product are finalized locally.
* `etcPhenocamDaily` ZIP files contain JPEG images only; local META sidecars
  remain covered by the cleanup manifest without entering the data object.
* Carbon Portal credentials require exactly two non-empty lines, with or
  without a final newline.
* Upload now rejects missing CPauth tokens and unsafe registration markers
  before the data PUT, while retaining the completed registration across
  retryable PUT failures.
* The base upload timer now matches the default capture schedule, and systemd
  service timeouts cover the complete sequential ICOS request limits.
* Installer verification excludes Git internals, checks the complete ICOS
  runtime set and re-executes safe RAM-disk initialization during upgrades.
* USB handlers honour configured mount bases and no longer remove queue
  temporary files outside the capture lock.



## [dev/v1.8.0]

The v1.8.0 section is derived from the Git difference between
`dev/v1.7.0` and `dev/v1.8.0`.

### Added

* Optional integration with Phenocam Vision Edge v0.2.3.
* Installation of the Vision Edge runtime in `/opt/phenocam-vision-edge-0.2.3`.
* `VISION_EDGE_ENABLED` as settings field 24, accepting only `on` or `off` and defaulting to `off`.
* `VISION_EDGE_MODE` as settings field 25, accepting the metadata-only, annotation, detected-region blurring or deletion actions.
* `detection_manager.sh` for processing queued pairs before upload.
* `detection_metadata.py` for validating and atomically maintaining detection state in the existing `.meta` file.
* Detection states `pending`, `vision`, `off` and `ready`, without a separate marker file.
* Recovery of a valid Vision Edge metadata result that has not yet received the OSCARS integration fields.
* Recovery of delete mode when the JPEG was removed but its `.meta` file remains.
* Upload eligibility checks that accept only `off` and `ready` pairs.
* Unit and shell tests for detection metadata, queue processing, upload eligibility and Vision Edge configuration.
* `TESTING.md` with the commands and scope of the v1.8.0 test suites.

### Changed

* `phenocam-upload.sh` now validates the Vision Edge configuration, processes detection and then drains upload queues under the existing `upload.lock`.
* Detection runs in USB, SD and RAM order before upload-method and Internet-route checks.
* Completed `off` and `ready` pairs are skipped by later detection cycles; pending pairs can be retried.
* `metadata` mode retains the original JPEG and records the detection result.
* Positive annotation and detected-region blurring results atomically replace the queued JPEG using the same filename; negative results retain the original JPEG.
* Positive `delete` results remove the queued JPEG and metadata pair; negative results retain the pair.
* The uploader postpones pairs whose detection metadata is missing, incomplete or invalid.
* Existing 23-field settings files remain valid and receive safe internal defaults.
* Detection-setting validation is separate from general settings loading, so invalid detection-only values do not stop capture from queuing new pairs.
* New configuration files created by the installer contain explicit detection settings as fields 24 and 25; existing configuration files are not overwritten.
* The runtime version marker is `dev/v1.8.0`.
* The installer deploys Python runtime scripts in addition to shell scripts.
* Project documentation now describes the v1.8.0 installation, configuration, architecture, metadata, operations, tests and failure handling.

The capture entry point, capture timer, queue-selection logic and
`capture.lock` are unchanged by the Vision Edge integration.

### Security

* Vision Edge configuration values are selected through fixed allowlists and are not passed to a general shell evaluator.
* The installer requires Python 3.13 and verifies `python3-venv` before installing Vision Edge.
* The Vision Edge v0.2.3 archive is verified against a SHA-256 value fixed in `install.sh`.
* The installed package entry point, model and model receipt are verified against fixed SHA-256 values.
* The Vision Edge source installer must be executable and not a symbolic link.
* The installed runtime is assigned to `root:root` and external write permissions are removed.
* Detection metadata updates use a temporary file and `os.replace`, preserve the original file mode and reject symbolic links or a replaced source file.
* Detection metadata validation rejects duplicate sections or fields, unsupported values, incorrect software or model identity, inconsistent class counts and outputs that do not match the selected mode.

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
