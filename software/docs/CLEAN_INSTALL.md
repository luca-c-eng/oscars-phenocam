# Clean Installation

This guide describes a clean installation of OSCARS-PHENOCAM `dev/v1.7.0`.

For configuration details, see [Configuration](CONFIGURATION.md).

---

## Requirements

Before starting, make sure the Raspberry Pi has:

* Raspberry Pi OS 64-bit based on Debian 13 `trixie`
* an active internet connection
* a connected camera supported by `rpicam-still`
* a regular user account with `sudo` privileges

Do not run the installer as `root`.

---

## Install OSCARS-PHENOCAM

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.7.0/install.sh | bash
```

The installer:

* verifies the operating system, architecture, network, and required commands;
* installs `git` and `exiftool`;
* clones the `dev/v1.7.0` branch into `/opt/oscars-phenocam`;
* deploys the runtime files to `/usr/local/lib/phenocam`;
* creates the `phenocam` system user and runtime directories;
* creates the configuration files in `/etc/phenocam`;
* generates the SSH key pair used for SFTP;
* installs the `systemd` units, USB rules, and log rotation;
* prepares the RAM-backed queue;
* enables the capture, upload, and startup-test timers for the next boot.

Existing configuration files are not overwritten.

---

## Configure the Station

Set the station name and acquisition parameters:

```bash
sudo nano /etc/phenocam/settings.txt
```

At minimum, replace the default station name on the first line.

Then configure at least one upload method.

### FTP

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

### SFTP

SFTP requires:

* one or more hosts in `/etc/phenocam/server.txt`;
* the SFTP username in `/etc/phenocam/settings.txt`;
* the server fingerprints in `/etc/phenocam/known_hosts`;
* authorization of the generated public key on the remote server.

See [Configuration](CONFIGURATION.md) for the required formats.

---

## Reboot

After completing the configuration, reboot the Raspberry Pi:

```bash
sudo reboot
```

The timers enabled by the installer will start automatically after boot.

---

## Verify the Installation

Check the camera:

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
```

Check the enabled services and timers:

```bash
sudo systemctl status \
  phenocam-init.service \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Check the scheduled executions:

```bash
systemctl list-timers 'phenocam-*' --all
```

Check the runtime log:

```bash
sudo tail -n 50 /var/log/phenocam/phenocam.log
```

For operational commands and diagnostics, see [Operations](OPERATIONS.md).

---

[Back to the project README](../../README.md)
