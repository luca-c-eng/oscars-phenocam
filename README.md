# OSCARS-PHENOCAM
[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.7.0-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System — PhenoCam Software**

Raspberry Pi-based phenological camera system for automated image acquisition and upload.  
Part of the [OSCARS](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system) Open Science project (EU grant 101129751).

---

## Overview

The software operates as an autonomous acquisition and transfer pipeline managed by `systemd`.

During each scheduled capture cycle, it:

1. verifies that the current station time is inside the configured acquisition window;
2. captures a JPEG image;
3. generates the corresponding `.meta` sidecar;
4. stores the image and metadata pair in the selected queue.

A separate upload service periodically processes the queued pairs and transfers them through the configured upload protocols.

Capture and upload therefore operate independently through dedicated services and timers.

---

## Core Features

* Visible-light image capture through `rpicam-still`, with `libcamera-still` fallback

* Scheduled captures at `:00` and `:30` of every hour

* Configurable daily acquisition window using a fixed UTC offset

* Standardized file naming:

  ```text
  SITENAME_YYYY_MM_DD_HHMMSS.jpg
  SITENAME_YYYY_MM_DD_HHMMSS.meta
  ```

* One structured `.meta` sidecar for every JPEG image

* Software version, build, system-health, network, capture, and EXIF metadata

* Three-level storage queue:

  ```text
  RAMDISK → USB → SD card
  ```

* Automatic queue retention when uploads fail

* FTP and SFTP support

* Simultaneous FTP and SFTP operation when both are configured

* Multiple SFTP destination support

* USB hot-plug handling

* Raspberry Pi temperature, throttling, and undervoltage monitoring

* Dedicated runtime user, file locking, atomic queue writes, and hardened `systemd` services

* Automatic capture-and-upload test cycle after boot

---

## Runtime Flow

The primary queue is stored in `/run/phenocam`, on a dynamically sized RAM-backed filesystem.

When the configured minimum RAM space is unavailable, image and metadata pairs are redirected to a writable USB queue. If USB storage is unavailable or above its configured usage threshold, the SD-card queue is used.

If the SD-card usage threshold is reached, the capture is skipped.

The upload service drains queues in the following order:

1. USB queue
2. SD-card queue
3. RAM queue

A local image and metadata pair is removed only after all enabled upload targets complete successfully.

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

The sidecar records station and network information, acquisition time, software version and build, Raspberry Pi health data, fixed capture parameters, and the complete EXIF output extracted from the JPEG.

---

## Documentation

* [Installation](software/docs/CLEAN_INSTALL.md)
* [Configuration](software/docs/CONFIGURATION.md)
* [Operations](software/docs/OPERATIONS.md)
* [Metadata format](software/docs/METADATA.md)
* [System health and thermal monitoring](software/docs/THERMAL_MONITORING.md)
* [Changelog](software/CHANGELOG.md)
* [Software architecture](software/docs/ARCHITECTURE.md)



---

## License

OSCARS-PHENOCAM is released under the [BSD 3-Clause License](LICENSE).
