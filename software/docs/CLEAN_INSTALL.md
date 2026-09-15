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
7. generates the
