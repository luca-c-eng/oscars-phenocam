# Configuration

OSCARS-PHENOCAM configuration files are stored in:

```text
/etc/phenocam/
```

They are created during installation and are not overwritten when the installer is run again.

---

## Configuration Files

| File                    | Purpose                                                       |
| ----------------------- | ------------------------------------------------------------- |
| `settings.txt`          | Station, acquisition, storage, network, and metadata settings |
| `server.txt`            | SFTP destination hosts                                        |
| `ftp_credentials.txt`   | FTP connection parameters                                     |
| `known_hosts`           | Trusted SFTP server fingerprints                              |
| `keys/phenocam_key`     | SFTP private key                                              |
| `keys/phenocam_key.pub` | SFTP public key                                               |

Configuration files are owned by `root:phenocam`. Edit them using `sudo`.

---

## Main Settings

Edit:

```bash
sudo nano /etc/phenocam/settings.txt
```

The file uses a positional format: one value per line.

Empty lines and lines beginning with `#` are ignored. Therefore, the positions below refer to non-empty, non-comment lines.

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
```

### Settings Reference

| Pos. | Variable           | Initial value         | Effective behaviour                                          |
| ---: | ------------------ | --------------------- | ------------------------------------------------------------ |
|    1 | `SITENAME`         | `mysite`              | Used in filenames, metadata, and remote paths                |
|    2 | `UTC_OFFSET`       | `+1`                  | Sets the fixed station time offset                           |
|    3 | `TZ_LABEL`         | `UTC+1`               | Read from the file, then regenerated from `UTC_OFFSET`       |
|    4 | `START_HOUR`       | `6`                   | Start of the capture window, inclusive                       |
|    5 | `END_HOUR`         | `22`                  | End of the capture window, exclusive                         |
|    6 | `INTERVAL_MIN`     | `30`                  | Read and exported, but not used in v1.7.0                    |
|    7 | `IFACE`            | `auto`                | Explicit network interface or automatic selection            |
|    8 | `SFTP_USER`        | `phenocam`            | Remote username used by SFTP                                 |
|    9 | `NET_MODE`         | `auto`                | Network selection mode: `auto`, `ethernet`, or `wifi`        |
|   10 | `RAM_MIN_FREE_MB`  | `20`                  | Minimum free RAM queue space before spillover                |
|   11 | `SD_MAX_USED_PCT`  | `80`                  | SD usage threshold above which capture is skipped            |
|   12 | `USB_MOUNT_BASES`  | `/media:/mnt`         | Colon-separated mount locations scanned for writable storage |
|   13 | `USB_MAX_USED_PCT` | `90`                  | USB usage threshold before falling back to SD                |
|   14 | `REMOTE_LAYOUT`    | `general`             | Remote directory layout: `general` or `icos`                 |
|   15 | `SITE_LAT`         | `nd`                  | Latitude written to each `.meta` file                        |
|   16 | `SITE_LON`         | `nd`                  | Longitude written to each `.meta` file                       |
|   17 | `SITE_ELEV_M`      | `nd`                  | Elevation written to each `.meta` file                       |
|   18 | `SITE_START_DATE`  | `nd`                  | Site start date written to each `.meta` file                 |
|   19 | `SITE_END_DATE`    | `nd`                  | Site end date written to each `.meta` file                   |
|   20 | `SITE_NIMAGE`      | `nd`                  | Value written as `nimage` in each `.meta` file               |
|   21 | `BOARD`            | detected or `unknown` | Read and exported, but not used after configuration loading  |
|   22 | `CAMERA_MODEL`     | `imx708`              | Read and exported, but not used after configuration loading  |
|   23 | `CAPTURE_TIMEOUT`  | `30000`               | Camera warm-up time in milliseconds                          |

The first six effective values are mandatory. The remaining values use internal fallbacks when omitted.

---

## Station Time

`UTC_OFFSET` accepts:

* `0`, `+0`, or `-0`;
* signed offsets from `-14` to `+14`;
* optional minute components such as `+5:30`.

The station uses a fixed UTC offset. Daylight-saving time is not applied.

`TZ_LABEL` is generated from `UTC_OFFSET`; changing line 3 independently has no runtime effect.

The acquisition window is evaluated as:

```text
START_HOUR <= current station hour < END_HOUR
```

For example:

```text
START_HOUR = 6
END_HOUR   = 22
```

allows captures from hour `06` through hour `21`.

An acquisition window crossing midnight is not supported by the current comparison logic.

---

## Capture Interval

`INTERVAL_MIN` is currently read from line 6 but does not control the capture schedule.

The effective schedule is defined by `phenocam-capture.timer`:

```ini
OnCalendar=*-*-* *:00,30:00 UTC
```

Therefore, v1.7.0 triggers the capture service at minutes `00` and `30` of every hour.

To change the current system schedule, create a `systemd` override:

```bash
sudo systemctl edit phenocam-capture.timer
```

For example, a 15-minute schedule requires:

```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* *:00,15,30,45:00 UTC
```

Then apply it:

```bash
sudo systemctl daemon-reload
sudo systemctl restart phenocam-capture.timer
```

Line 6 must remain present because the settings parser requires the first six values.

---

## Network Selection

Network interface selection follows this order:

1. the interface explicitly specified by `IFACE`;
2. an Ethernet or Wi-Fi interface matching `NET_MODE`;
3. the interface selected by the default internet route;
4. the first non-loopback interface with a global IPv4 address.

Use:

```text
auto
```

for both `IFACE` and `NET_MODE` when no specific interface is required.

---

## FTP Configuration

Edit:

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

Add five non-empty values in this exact order:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

`FTP_PORT` must be numeric.

The uploader always uses the `ftp://` protocol. Setting port `22` does not enable SFTP.

FTP credentials are stored as plain text and must not be committed to the repository.

---

## SFTP Configuration

### 1. Authorize the Public Key

Display the generated public key:

```bash
sudo cat /etc/phenocam/keys/phenocam_key.pub
```

Install this public key on every destination server.

Never share the private key:

```text
/etc/phenocam/keys/phenocam_key
```

### 2. Configure the Hosts

Edit:

```bash
sudo nano /etc/phenocam/server.txt
```

Add one hostname or IP address per line. Empty lines and comments are ignored.

### 3. Configure the Username

Set `SFTP_USER` in position 8 of:

```text
/etc/phenocam/settings.txt
```

### 4. Register Server Fingerprints

For each server, run:

```bash
sudo ssh-keyscan -H <hostname> |
  sudo tee -a /etc/phenocam/known_hosts >/dev/null
```

SFTP uses strict host-key checking. Uploads fail when the destination is absent from `known_hosts`.

---

## Upload Activation

Upload protocols are enabled automatically from their effective configuration.

| `server.txt` | `ftp_credentials.txt` | Active upload |
| ------------ | --------------------- | ------------- |
| Empty        | Empty or incomplete   | None          |
| Configured   | Empty or incomplete   | SFTP          |
| Empty        | Five valid values     | FTP           |
| Configured   | Five valid values     | SFTP and FTP  |

When both protocols are active, a queued pair is retained until both uploads succeed.

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

Configuration files are read at the beginning of each capture or upload cycle. Changes take effect on the next execution.

Check upload prerequisites with:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

For service management and runtime checks, see [Operations](OPERATIONS.md).

---

[Clean installation](CLEAN_INSTALL.md) · [Back to the project README](../../README.md)
