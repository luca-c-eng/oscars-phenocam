# Clean Installation

This guide describes a clean installation of OSCARS-PHENOCAM `dev/v0.1.0`.

## Requirements

- Raspberry Pi OS 64-bit based on Debian 13 `trixie`;
- a regular account with `sudo` privileges;
- Internet connectivity during installation;
- `rpicam-still` and a supported camera;
- Python 3.13 for Phenocam Vision Edge.

Do not run the installer as `root`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v0.1.0/install.sh | bash
```

The installer verifies the platform, installs the required packages, deploys
the runtime, verifies Phenocam Vision Edge v0.2.3, creates the service account,
installs the systemd units and creates the protected configuration files.

On a new installation it also generates one random capture offset in the range
`0–29`, writes it as `CAPTURE_MINUTE`, and uses it to generate the capture and
upload timer overrides. The value is not regenerated during normal updates.
Missed timer events are not replayed after downtime, and the diagnostic startup
cycle is not enabled automatically; therefore rebooting does not create an
off-schedule scientific image.

Supported earlier layouts containing 23, 25, 27 or 28 effective fields are
extended to the 34-field ICOS layout without changing their existing values.
The persistent capture offset is generated from their configured acquisition
interval. Other incomplete layouts are left untouched and reported for manual
review.

## Configure the Station

Edit the positional settings:

```bash
sudo nano /etc/phenocam/settings.txt
```

At minimum, configure:

- field 1: `SITENAME`;
- field 29: `CP_ENVIRONMENT` (`staging` initially);
- field 30: `CP_SUBMITTER_ID` supplied by Carbon Portal staff;
- field 31: canonical station URI;
- field 32: canonical instrument URI;
- field 33: confirmed station-specific `Lxx_Fxx` filename suffix.

The default capture interval is 30 minutes. If fields 6 or 34 are changed,
apply the new stable schedule:

```bash
sudo /usr/local/lib/phenocam/bin/phenocam-configure-schedule.sh
```

## Configure the Station Account

The account is not stored in `settings.txt`. Edit:

```bash
sudo nano /etc/phenocam/cp_credentials.txt
```

Enter exactly:

```text
account-email@example.org
account-password
```

Each installation uses the account authorized for its station. Keep
`CP_ENVIRONMENT=staging` for the initial end-to-end tests.

## Reboot and Verify

```bash
sudo reboot
```

After reboot:

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
systemctl list-timers 'phenocam-*' --all
sudo systemctl status phenocam-init.service phenocam-capture.timer phenocam-upload.timer
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

To request one complete queue-processing cycle manually:

```bash
sudo systemctl start phenocam-upload.service
```

[Configuration](CONFIGURATION.md) | [Operations](OPERATIONS.md) | [Troubleshooting](TROUBLESHOOTING.md)
