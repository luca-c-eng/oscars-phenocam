# OSCARS-PHENOCAM

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System - PhenoCam Software**

Raspberry Pi-based phenological camera system for automated image acquisition,
optional privacy-aware edge detection and upload.

Part of the [OSCARS](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system) Open Science project (EU grant 101129751).

---

## Overview

OSCARS-PHENOCAM operates as an autonomous capture, queue-processing and transfer
pipeline managed by `systemd`.

During each scheduled capture cycle, it:

1. verifies that the current station time is inside the configured acquisition window;
2. captures a JPEG image;
3. generates the corresponding `.meta` sidecar;
4. stores the image and metadata pair in the selected queue.

A separate service periodically processes queued pairs. It applies the
configured detection behavior first and then attempts the configured uploads.

Capture uses `capture.lock`. Detection and upload run sequentially under the
separate `upload.lock`.

---

## Core Features

- JPEG image capture through `rpicam-still`, with `libcamera-still` fallback
- capture timer scheduled at minutes `00` and `30` of every hour in UTC
- configurable daily acquisition window using a fixed UTC offset
- standardized file naming:

  ```text
  SITENAME_YYYY_MM_DD_HHMMSS.jpg
  SITENAME_YYYY_MM_DD_HHMMSS.meta
  ```

- one structured `.meta` sidecar for every queued JPEG
- software, system-health, network, capture, EXIF and detection metadata
- three-level storage queue:

  ```text
  RAM -> USB -> SD
  ```

- optional [Phenocam Vision Edge](https://github.com/e-tufarini-terrasystem/phenocam-vision-edge) v0.2.3 integration
- `metadata`, `annotated`, `privacy` and `delete` detection modes
- detection disabled by default
- retention of queued pairs when an enabled upload fails
- FTP and SFTP support, including simultaneous use
- multiple SFTP destination support
- USB hot-plug handling
- Raspberry Pi temperature, throttling and undervoltage monitoring
- startup capture-and-upload test cycle
- dedicated runtime user, file locking, atomic queue publication and hardened `systemd` services

---

## Runtime Flow

The primary queue is stored in `/run/phenocam/queue` on a dynamically sized RAM-backed filesystem.

When available RAM space is below `RAM_MIN_FREE_MB`, the pair is redirected to the first available writable USB queue whose usage is below `USB_MAX_USED_PCT`.

If a suitable USB queue is unavailable, the SD-card queue is used. If SD fallback is required and SD usage is at or above `SD_MAX_USED_PCT`, the captured JPEG and metadata files are removed from staging and the cycle completes without queuing the pair.

Detection and upload process queues in this order:

1. USB
2. SD
3. RAM

Detection runs before the Internet-route check. The `.meta` file records the
processing state, preventing completed pairs from being detected again. Pending
pairs can be retried. Only pairs marked `off` or `ready` are eligible for
upload.

With detection enabled, `annotated` and `privacy` can atomically replace the
queued JPEG after a positive result. `delete` removes the pair only after a
positive detection and successful requested processing.

When both FTP and SFTP are configured, both transfers are attempted for each
eligible pair. Local files are removed only after every enabled upload
succeeds.

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

Queue processing then adds:

```text
[detection]
```

The sidecar stores station and network information, acquisition time, installed
software information, Raspberry Pi health values, fixed capture parameters,
EXIF data and the effective detection state.

---

## Quick Start

On Raspberry Pi OS 64-bit based on Debian 13 `trixie`, run the installer as a
regular user with `sudo` privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v0.1.0/install.sh | bash
```

After installation, configure `/etc/phenocam/settings.txt`, configure FTP or
SFTP when transfer is required, and reboot.

See [Clean installation](software/docs/CLEAN_INSTALL.md) for the complete
procedure.

---

## Documentation

* [Clean installation](software/docs/CLEAN_INSTALL.md)
* [Configuration](software/docs/CONFIGURATION.md)
* [Software architecture](software/docs/ARCHITECTURE.md)
* [Operations](software/docs/OPERATIONS.md)
* [Metadata format](software/docs/METADATA.md)
* [System health and thermal monitoring](software/docs/THERMAL_MONITORING.md)
* [Troubleshooting](software/docs/TROUBLESHOOTING.md)
* [Testing](software/docs/TESTING.md)
* [Changelog](software/CHANGELOG.md)
* [Project provenance](PROVENANCE.md)

---

## License

OSCARS-PHENOCAM is released under the [BSD 3-Clause License](LICENSE).
