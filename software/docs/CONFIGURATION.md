# Configuration

OSCARS-PHENOCAM reads its runtime configuration from:

```text
/etc/phenocam/
```

The installer creates the configuration files only when they do not already exist.

---

## Configuration Files

| Path                    | Purpose                                                      |
| ----------------------- | ------------------------------------------------------------ |
| `settings.txt`          | Station, acquisition, storage, network and metadata settings |
| `server.txt`            | SFTP destination hosts                                       |
| `ftp_credentials.txt`   | FTP connection parameters                                    |
| `known_hosts`           | Trusted SFTP server fingerprints                             |
| `keys/phenocam_key`     | SFTP private key                                             |
| `keys/phenocam_key.pub` | SFTP public key                                              |

The installer applies these permissions:

| Files                                                              | Owner               |  Mode |
| ------------------------------------------------------------------ | ------------------- | ----: |
| `settings.txt`, `server.txt`, `ftp_credentials.txt`, `known_hosts` | `root:phenocam`     | `640` |
| `keys/phenocam_key`                                                | `phenocam:phenocam` | `600` |
| `keys/phenocam_key.pub`                                            | `phenocam:phenocam` | `644` |

Edit protected files using `sudo`.

---

## Main Settings

Edit:

```bash
sudo nano /etc/phenocam/settings.txt
```

The file uses a positional format with one effective value per line.

Blank lines and comment lines are removed before positions are assigned. A blank line therefore cannot represent an empty field, and the order of the values must not change.

The installer creates:

```text
mysite
+1
UTC+1
6
22
30
auto
phenocam
auto
20
80
/media:/mnt
90
general
nd
nd
nd
nd
nd
nd
unknown
imx708
30000
off
privacy
```

## Settings Reference

| Pos. | Variable           | Initial value               | Effective behaviour                                                   |
| ---: | ------------------ | --------------------------- | --------------------------------------------------------------------- |
|    1 | `SITENAME`         | `mysite`                    | Used in filenames, metadata and remote paths                          |
|    2 | `UTC_OFFSET`       | `+1`                        | Defines the fixed station time offset                                 |
|    3 | `TZ_LABEL`         | `UTC+1`                     | Required by the positional parser, then regenerated from `UTC_OFFSET` |
|    4 | `START_HOUR`       | `6`                         | Start of the acquisition window, inclusive                            |
|    5 | `END_HOUR`         | `22`                        | End of the acquisition window, exclusive                              |
|    6 | `INTERVAL_MIN`     | `30`                        | Read and exported, but not used by the capture timer                  |
|    7 | `IFACE`            | `auto`                      | Explicit network interface or automatic selection                     |
|    8 | `SFTP_USER`        | `phenocam`                  | Remote username used for SFTP                                         |
|    9 | `NET_MODE`         | `auto`                      | Selects the `auto`, `ethernet` or `wifi` interface-resolution branch  |
|   10 | `RAM_MIN_FREE_MB`  | `20`                        | RAM queue is used when its free space is at or above this value       |
|   11 | `SD_MAX_USED_PCT`  | `80`                        | Applied only when SD fallback is required                             |
|   12 | `USB_MOUNT_BASES`  | `/media:/mnt`               | Colon-separated locations scanned for writable mounted filesystems    |
|   13 | `USB_MAX_USED_PCT` | `90`                        | USB is used only when its usage is below this value                   |
|   14 | `REMOTE_LAYOUT`    | `general`                   | Remote directory layout: `general` or `icos`                          |
|   15 | `SITE_LAT`         | `nd`                        | Written as `lat` in metadata                                          |
|   16 | `SITE_LON`         | `nd`                        | Written as `lon` in metadata                                          |
|   17 | `SITE_ELEV_M`      | `nd`                        | Written as `elev` in metadata                                         |
|   18 | `SITE_START_DATE`  | `nd`                        | Written as `start_date` in metadata                                   |
|   19 | `SITE_END_DATE`    | `nd`                        | Written as `end_date` in metadata                                     |
|   20 | `SITE_NIMAGE`      | `nd`                        | Written as `nimage` in metadata                                       |
|   21 | `BOARD`            | detected value or `unknown` | Read and exported, but not consumed by the runtime scripts            |
|   22 | `CAMERA_MODEL`     | `imx708`                    | Read and exported, but not consumed by the runtime scripts            |
|   23 | `CAPTURE_TIMEOUT`  | `30000`                     | Camera warm-up time in milliseconds                                   |
|   24 | `VISION_EDGE_ENABLED` | `off`                    | Enables (`on`) or disables (`off`) detection                           |
|   25 | `VISION_EDGE_MODE` | `privacy`                   | Selects `metadata`, `annotated`, `privacy` or `delete`                 |

The first six effective values are mandatory. Later values use internal defaults when they are absent.

Existing 23-field configuration files remain valid. When positions 24 and 25
are absent, the software uses `off` and `privacy` respectively.

A non-numeric `CAPTURE_TIMEOUT` is replaced with `30000`.

---

## Station Time

`UTC_OFFSET` accepts:

* `0`, `+0` or `-0`;
* a signed hour from `-14` to `+14`;
* an optional minute component between `00` and `59`, such as `+5:30`.

The software exports a fixed POSIX timezone from this value. Daylight-saving-time changes are not applied.

`TZ_LABEL` is regenerated from `UTC_OFFSET`. Changing position 3 independently has no runtime effect, but the value must remain present because it is one of the six mandatory fields.

The acquisition window is evaluated as:

```text
START_HOUR <= current station hour < END_HOUR
```

For example:

```text
START_HOUR = 6
END_HOUR   = 22
```

allows acquisition from hour `06` through hour `21`.

The current comparison does not support a window that crosses midnight.

---

## Capture Schedule

`INTERVAL_MIN` is read from position 6 but is not used to schedule captures.

The effective schedule is defined in `phenocam-capture.timer`:

```ini
OnCalendar=*-*-* *:00,30:00 UTC
```

The capture service is therefore requested at minutes `00` and `30` of every hour in UTC.

To change the schedule, create a `systemd` override:

```bash
sudo systemctl edit phenocam-capture.timer
```

For example, to request a capture every 15 minutes:

```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* *:00,15,30,45:00 UTC
```

Apply the override:

```bash
sudo systemctl daemon-reload
sudo systemctl restart phenocam-capture.timer
```

Position 6 must remain in `settings.txt` even when the timer is overridden.

---

## Vision Edge Detection

Phenocam Vision Edge v0.2.3 is installed by `install.sh`. Detection is executed
from the upload cycle, inside the existing upload lock and before the Internet
availability check.

`VISION_EDGE_ENABLED` accepts only:

| Value | Behaviour |
| ----- | --------- |
| `off` | Does not run inference. The queued pair is marked as detection-disabled and becomes eligible for upload. |
| `on`  | Runs Vision Edge on each queued pair that has not already completed detection. |

`VISION_EDGE_MODE` accepts only:

| Value       | Vision Edge action |
| ----------- | ------------------ |
| `metadata`  | Updates detection metadata without modifying the JPEG. |
| `annotated` | Replaces the queued JPEG with the annotated image when an enabled detection exists. |
| `privacy`   | Replaces the queued JPEG with the privacy-blurred image when an enabled detection exists. |
| `delete`    | Deletes the queued JPEG and metadata only when an enabled detection exists. |

When detection is `off`, the selected mode is still recorded in the metadata as
`filter_mode`; no inference action is performed.

When `annotated`, `privacy` or `delete` produces no enabled detection, the
original JPEG remains queued and the metadata records a completed negative
result.

The mode is selected internally from this fixed list. Configuration values are
never evaluated as shell commands or forwarded as arbitrary command-line
arguments.

Detection state is stored in the pair's `.meta` file. Later cycles skip pairs
already marked `off` or `ready`. Therefore, changing positions 24 or 25 affects
only pairs that have not yet completed detection.

Pairs already present during an upgrade from v1.7.0 have no detection state and
are processed using the effective v1.8.0 configuration. With an unchanged
23-field file, the backward-compatible default is `off`.

An unsupported value in either position stops the upload cycle before queue
processing. Capture remains active because detection validation is deliberately
separate from general settings loading.

---

## Network Selection

Network resolution first examines `IFACE`.

* If `IFACE` contains an existing interface name other than `auto`, that interface is returned.
* If the requested interface does not exist, selection continues according to `NET_MODE`.

`NET_MODE` selects one of three branches:

| Value           | Behaviour                                                                                                                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `ethernet`      | Returns the first interface with a global IPv4 address whose name begins with `eth` or `en`                                                |
| `wifi`          | Returns the first interface with a global IPv4 address whose name begins with `wlan` or `wl`                                               |
| `auto`          | Uses the interface selected by the route to `1.1.1.1`; if unavailable, returns the first non-loopback interface with a global IPv4 address |
| any other value | Follows the same branch as `auto`                                                                                                          |

The `ethernet` and `wifi` branches do not continue to default-route selection when no matching interface is found.

Use:

```text
auto
```

for both `IFACE` and `NET_MODE` when no interface restriction is required.

---

## Storage Selection

A completed JPEG and metadata pair is assigned using this sequence:

1. Use the RAM queue when its free space is at or above `RAM_MIN_FREE_MB`.
2. Otherwise, locate the first mounted and writable filesystem below `USB_MOUNT_BASES`.
3. Use its USB queue when usage is below `USB_MAX_USED_PCT`.
4. Otherwise, attempt to use the SD queue.
5. If SD usage is at or above `SD_MAX_USED_PCT`, remove the captured pair from staging and complete the cycle without queuing it.

`SD_MAX_USED_PCT` is not checked while the RAM queue or a suitable USB queue can be used.

---

## FTP Configuration

Edit:

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

Add at least five effective values in this order:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

Blank and comment lines are excluded when the file is read.

`FTP_PORT` must contain only digits. The uploader always constructs an `ftp://` URL; using port `22` does not enable SFTP.

FTP credentials are stored as plain text and must not be committed to the repository.

---

## SFTP Configuration

### 1. Authorize the Public Key

Display the generated public key:

```bash
sudo cat /etc/phenocam/keys/phenocam_key.pub
```

Authorize it on every destination server.

Do not share the private key:

```text
/etc/phenocam/keys/phenocam_key
```

### 2. Configure Destination Hosts

Edit:

```bash
sudo nano /etc/phenocam/server.txt
```

Add one hostname or IP address per line.

Use no leading or trailing whitespace. Comment lines must begin directly with `#`.

### 3. Configure the Username

Set `SFTP_USER` in position 8 of:

```text
/etc/phenocam/settings.txt
```

### 4. Register Server Fingerprints

For each destination, run:

```bash
sudo ssh-keyscan -H <hostname> |
  sudo tee -a /etc/phenocam/known_hosts >/dev/null
```

SFTP uses:

```text
BatchMode=yes
StrictHostKeyChecking=yes
```

An unknown server key or an unavailable private key causes the SFTP upload to fail.

---

## Upload Activation

SFTP is enabled when `server.txt` contains at least one non-empty, non-comment line.

FTP is enabled when `ftp_credentials.txt` contains at least five effective lines and positions 1, 2, 4 and 5 do not contain these example placeholders:

```text
YOUR_FTP_HOST_OR_IP
YOUR_FTP_PORT
your_ftp_username
your_ftp_password
```

The remote-base value in position 3 is not checked against an example placeholder during activation.

| `server.txt`                | FTP configuration | Attempted upload |
| --------------------------- | ----------------- | ---------------- |
| No effective host           | Disabled          | None             |
| At least one effective host | Disabled          | SFTP             |
| No effective host           | Enabled           | FTP              |
| At least one effective host | Enabled           | SFTP, then FTP   |

Activation does not guarantee that credentials, hosts or remote services are valid.

When both protocols are enabled, both are attempted for each pair. Local files are removed only when every enabled upload succeeds.

If one enabled target succeeds and another fails, the pair remains queued and is offered to all enabled targets again during the next upload cycle.

---

## Remote Directory Layout

`REMOTE_LAYOUT` accepts `general` or `icos`.

| Layout    | SFTP path           | FTP path                            |
| --------- | ------------------- | ----------------------------------- |
| `general` | `SITENAME/YYYY/MM/` | `FTP_REMOTE_BASE/SITENAME/YYYY/MM/` |
| `icos`    | `data/SITENAME/`    | `FTP_REMOTE_BASE/data/SITENAME/`    |

Any other value causes the upload attempt to fail.

---

## Apply and Verify

Configuration files are read at the beginning of each capture or upload cycle. Changes are therefore used by the next applicable execution.

Check upload prerequisites with:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

This diagnostic checks the presence or file size of selected upload files. It does not validate their complete effective configuration and does not perform a transfer.

For service management and runtime checks, see [Operations](OPERATIONS.md).

---

[Clean installation](CLEAN_INSTALL.md) | [Back to the project README](../../README.md)
