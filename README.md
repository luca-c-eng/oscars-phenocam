# OSCARS-PHENOCAM

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.7.0-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System — PhenoCam Software**

Raspberry Pi-based phenological camera system for automated image acquisition and upload.
Part of the [OSCARS](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system) Open Science project (EU grant 101129751).

---

## Overview

OSCARS-PHENOCAM operates as an autonomous acquisition and transfer pipeline managed by `systemd`.

During each scheduled capture cycle, it:

1. verifies that the current station time is inside the configured acquisition window;
2. captures a JPEG image;
3. generates the corresponding `.meta` sidecar;
4. stores the image and metadata pair in the selected queue.

A separate upload service periodically processes queued pairs using the configured upload protocols.

Capture and upload use independent services, timers and lock files.

---

## Core Features

* JPEG image capture through `rpicam-still`, with `libcamera-still` fallback

* Capture timer scheduled at minutes `00` and `30` of every hour in UTC

* Configurable daily acquisition window using a fixed UTC offset

* Standardized file naming:

  ```text
  SITENAME_YYYY_MM_DD_HHMMSS.jpg
  SITENAME_YYYY_MM_DD_HHMMSS.meta
  ```

* One structured `.meta` sidecar for every JPEG image

* Software, system-health, network, capture and EXIF metadata

* Three-level storage queue:

  ```text
  RAM → USB → SD
  ```

* Retention of queued pairs when an enabled upload fails

* FTP and SFTP support

* FTP and SFTP operation within the same upload cycle when both are configured

* Multiple SFTP destination support

* USB hot-plug handling

* Raspberry Pi temperature, throttling and undervoltage monitoring

* Startup capture-and-upload test cycle

* Dedicated runtime user, file locking, temporary queue filenames and hardened `systemd` services

---

## Runtime Flow

The primary queue is stored in `/run/phenocam/queue` on a dynamically sized RAM-backed filesystem.

When available RAM space is below `RAM_MIN_FREE_MB`, the pair is redirected to the first available writable USB queue whose usage is below `USB_MAX_USED_PCT`.

If a suitable USB queue is unavailable, the SD-card queue is used. When SD fallback is required and SD usage is at or above `SD_MAX_USED_PCT`, the pair is not queued and the capture cycle fails.

The upload service processes queues in this order:

1. USB
2. SD
3. RAM

When both FTP and SFTP are configured, both transfers are attempted for each pair. Local files are removed only after every enabled upload succeeds.

---

## Metadata

Each `.meta` file contains:

```text
[system]
[phenocam]
[system_health]
[capture_params_fixed]
[exif]
```

The sidecar stores station and network information, acquisition time, installed software information, Raspberry Pi health values, fixed capture parameters and the EXIF data returned by `exiftool`.

---

## Documentation

* [Clean installation](software/docs/CLEAN_INSTALL.md)
* [Configuration](software/docs/CONFIGURATION.md)
* [Software architecture](software/docs/ARCHITECTURE.md)
* [Operations](software/docs/OPERATIONS.md)
* [Metadata format](software/docs/METADATA.md)
* [System health and thermal monitoring](software/docs/THERMAL_MONITORING.md)
* [Troubleshooting](software/docs/TROUBLESHOOTING.md)
* [Changelog](software/CHANGELOG.md)

---

## License

OSCARS-PHENOCAM is released under the [BSD 3-Clause License](LICENSE).
