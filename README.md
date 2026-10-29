# OSCARS-PHENOCAM

[![License: BSD 3-Clause](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](software/VERSION)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18800314.svg)](https://doi.org/10.5281/zenodo.18800314)

**Open and FAIR Integrated Phenology Monitoring System — PhenoCam Software**

OSCARS-PHENOCAM is an autonomous Raspberry Pi system for phenological image
acquisition and direct delivery of daily Level-0 products to the ICOS Carbon
Portal. It is part of the
[OSCARS project](https://oscars-project.eu/projects/open-and-fair-integrated-phenology-monitoring-system)
(EU grant 101129751).

## Runtime Flow

1. Capture JPEG images and generate matching metadata sidecars.
2. Optionally apply edge-based vision screening.
3. Build one uncompressed JPEG-only ZIP for each station-local calendar day.
4. Calculate the ZIP SHA-256 and register its JSON metadata package.
5. Upload the immutable ZIP to the ICOS data service.
6. Retain a receipt and remove verified source files only after confirmation.

## Main Features

- Raspberry Pi Camera Module 3 capture through `rpicam-still`
- configurable 1536 × 864, 2304 × 1296 or 4608 × 2592 resolution
- configurable JPEG quality from 1 to 100
- default 30-minute interval with one random, persistent installation offset
- station-local fixed time without daylight-saving changes
- structured image metadata and system-health values
- optional Phenocam Vision Edge v0.2.3 screening
- RAM, USB and SD queue hierarchy
- one uncompressed, JPEG-only daily Level-0 ZIP
- ICOS staging and production environments
- SHA-256-addressed two-step Carbon Portal upload
- immutable retry outbox, local receipts and verified cleanup
- dedicated runtime user, atomic queue publication and hardened systemd services

## Quick Start

On Raspberry Pi OS 64-bit based on Debian 13 `trixie`:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v0.1.0/install.sh | bash
```

Then configure:

```bash
sudo nano /etc/phenocam/settings.txt
sudo nano /etc/phenocam/cp_credentials.txt
sudo /usr/local/lib/phenocam/bin/phenocam-configure-schedule.sh
sudo reboot
```

New installations default to `staging`. Upload remains disabled until the
Carbon Portal submitter identifier, station URI, instrument URI and
station-specific account are configured.

## Documentation

- [Clean installation](software/docs/CLEAN_INSTALL.md)
- [Configuration](software/docs/CONFIGURATION.md)
- [Software architecture](software/docs/ARCHITECTURE.md)
- [Operations](software/docs/OPERATIONS.md)
- [Metadata format](software/docs/METADATA.md)
- [Testing](software/docs/TESTING.md)
- [Troubleshooting](software/docs/TROUBLESHOOTING.md)
- [Changelog](software/CHANGELOG.md)
- [Project provenance](PROVENANCE.md)

## License

OSCARS-PHENOCAM is released under the [BSD 3-Clause License](LICENSE).
