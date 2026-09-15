# Clean Installation

This guide describes a clean installation of OSCARS-PHENOCAM `dev/v1.7.0`.

For all configuration fields, see [Configuration](CONFIGURATION.md).

---

## Before Installation

Use a regular user account with `sudo` privileges.

Do not run the installer as `root`.

The installer expects:

* Raspberry Pi OS 64-bit based on Debian 13 `trixie`;
* `aarch64` architecture;
* a route to `1.1.1.1`;
* `rpicam-still`;
* `curl`;
* `sftp`;
* `flock`;
* `/usr/sbin/runuser`.

A different operating-system version or architecture produces a warning but does not stop the installer.

A missing network route, required command or `sudo` access stops installation.

A supported camera is required for acquisition, but the installer can finish when a camera is not currently detected.

---

## Install OSCARS-PHENOCAM

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.7.0/install.sh | bash
```

The installer:

1. checks the execution user, operating system, architecture, route and required commands;
2. installs `git` and `libimage-exiftool-perl`;
3. clones `dev/v1.7.0` into `/opt/oscars-phenocam`;
4. creates the `phenocam` system user;
5. deploys runtime files to `/usr/local/lib/phenocam`;
6. creates configuration files in `/etc/phenocam`;
7. generates the SFTP key pair;
8. installs `systemd` units, the USB rule and log rotation;
9. prepares `/run/phenocam`;
10. enables the startup, capture and upload timers for the next boot.

Existing configuration files are not overwritten.

---

## Configure the Station

Edit:

```bash
sudo nano /etc/phenocam/settings.txt
```

Replace the default station name on the first effective line and review the remaining values.

Configure at least one upload method.

### FTP

Edit:

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

### SFTP

SFTP requires:

* one or more destinations in `/etc/phenocam/server.txt`;
* `SFTP_USER` in `/etc/phenocam/settings.txt`;
* server fingerprints in `/etc/phenocam/known_hosts`;
* authorization of the generated public key on each destination.

Display the public key:

```bash
sudo cat /etc/phenocam/keys/phenocam_key.pub
```

Do not share the private key.

See [Configuration](CONFIGURATION.md) for the exact file formats.

---

## Reboot

After configuration, reboot:

```bash
sudo reboot
```

The timers enabled by the installer start after boot.

---

## Verify the Installation

Check the camera:

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
```

Check the main units:

```bash
sudo systemctl status \
  phenocam-init.service \
  run-phenocam.mount \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Check scheduled executions:

```bash
systemctl list-timers 'phenocam-*' --all
```

Check recent application events:

```bash
sudo tail -n 50 /var/log/phenocam/phenocam.log
```

For service management and diagnostics, see [Operations](OPERATIONS.md).

---

[Configuration](CONFIGURATION.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Back to the project README](../../README.md)
