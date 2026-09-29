# Troubleshooting

This guide covers failures and runtime conditions directly handled or reported
by OSCARS-PHENOCAM `dev/v1.8.0`.

For routine commands, see [Operations](OPERATIONS.md).

---

## First Checks

Check the timers and services:

```bash
sudo systemctl status \
  phenocam-init.service \
  run-phenocam.mount \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Check recent application events:

```bash
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

List scheduled executions:

```bash
systemctl list-timers 'phenocam-*' --all
```

Capture and upload services are `oneshot` units. An `inactive (dead)` state is normal after a successful execution; their timers should remain active.

---

## Installation Stops

### Installer Run as Root

The installer refuses to run when the current user is `root`.

Run it as a regular user with `sudo` privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.8.0/install.sh | bash
```

Do not prefix this command with `sudo`.

### No Network Route

The installer requires this command to succeed:

```bash
ip route get 1.1.1.1
```

If it fails, installation stops before package installation and repository download.

Inspect the network state:

```bash
ip link
ip -4 addr
ip route
```

### Required Command Missing

Installation stops when any of these commands is unavailable:

```text
rpicam-still
curl
sftp
flock
/usr/sbin/runuser
```

The installer installs `git`, `libimage-exiftool-perl` and `python3-venv` when
required. It then requires `/usr/bin/python3` to be Python 3.13 and verifies
that the `venv` module can be imported.

The Vision Edge installation step also invokes `mktemp`, `sha256sum` and `tar`
directly.

### Phenocam Vision Edge Installation Fails

The installer downloads only Phenocam Vision Edge v0.2.3 and verifies the
archive against the SHA-256 value fixed in `install.sh`.

Installation stops if:

* the v0.2.3 archive cannot be downloaded;
* the archive checksum does not match;
* archive extraction fails;
* the extracted package directory or installer is invalid;
* the upstream installer returns an error;
* the installed package, model or model receipt fails validation.

The expected runtime location is:

```text
/opt/phenocam-vision-edge-0.2.3
```

An existing file, directory or symbolic link at that path stops installation
when it does not pass validation. Inspect the path before deciding whether it
must be repaired or removed:

```bash
sudo ls -ld /opt/phenocam-vision-edge-0.2.3
sudo ls -l \
  /opt/phenocam-vision-edge-0.2.3/.venv/bin/python \
  /opt/phenocam-vision-edge-0.2.3/phenocam/__init__.py \
  /opt/phenocam-vision-edge-0.2.3/models/yolo26n-phenocam.onnx \
  /opt/phenocam-vision-edge-0.2.3/models/yolo26n-phenocam.json
```

The installer verifies fixed hashes for the installed package entry point,
model and model receipt. Replacing any of these files makes the runtime fail a
later installer validation.

---

## RAM Initialization Fails

Inspect the service:

```bash
sudo systemctl status phenocam-init.service
sudo journalctl -u phenocam-init.service -n 120 --no-pager
```

The initialization script performs explicit checks for:

```text
/etc/systemd/system/run-phenocam.mount
phenocam system user
```

It exits with an error when either is missing.

Check the mount:

```bash
systemctl status run-phenocam.mount
```

Check the runtime storage:

```bash
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
```

---

## Camera Is Not Detected

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
```

The diagnostic uses:

```text
rpicam-hello --list-cameras
```

and falls back to:

```text
libcamera-hello --list-cameras
```

If neither command exists, the diagnostic exits with an error.

After the installer requests camera activation, a reboot may be required:

```bash
sudo reboot
```

---

## No Image Is Available After a Cycle

Inspect the service and logs:

```bash
sudo systemctl status phenocam-capture.service
sudo journalctl -u phenocam-capture.service -n 100 --no-pager
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

| Condition                                                       | Executed behaviour                                                                      |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Outside the acquisition window                                  | Cycle returns successfully without capturing an image                                   |
| Invalid `settings.txt`                                          | Capture service fails                                                                   |
| Camera command unavailable or unsuccessful                      | Capture service fails                                                                   |
| Camera guard timeout reached                                    | Camera process is terminated and capture fails                                          |
| `exiftool` unavailable                                          | Metadata generation fails                                                               |
| SD fallback required and SD usage at or above `SD_MAX_USED_PCT` | Captured JPEG and metadata are removed; cycle returns successfully without queuing them |
| `capture.lock` already held                                     | Duplicate capture exits with an error                                                   |
| Timer event missed while powered off                            | Event is not replayed                                                                   |

`phenocam-capture.timer` uses:

```ini
Persistent=false
```

### Staging Cleanup

Staging cleanup occurs only after the acquisition-window check succeeds.

Files left in:

```text
/run/phenocam/staging
```

are therefore removed at the beginning of the next capture cycle that is inside the configured acquisition window.

A cycle outside the acquisition window does not clean staging.

---

## Startup Test Creates No Image

The startup service calls the standard capture entry point before calling upload.

The same acquisition-window check is applied. When the station is outside the window, the capture command returns successfully without creating an image, and the startup service continues with the upload request.

---

## Capture or Queue Processing Reports a Lock Error

The software uses separate non-blocking locks:

```text
/run/phenocam/capture.lock
/run/phenocam/upload.lock
```

A duplicate operation exits with an error when another instance of the same operation holds the corresponding lock.

Check the related service:

```bash
systemctl status phenocam-capture.service
systemctl status phenocam-upload.service
```

A lock file may remain on the filesystem after execution. Its presence does not prove that the lock is currently held.

---

## Detection or Upload Service Fails Before Queue Processing

Inspect the service and application log:

```bash
sudo systemctl status phenocam-upload.service
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

The upload entry point can stop before per-pair processing for these reasons:

| Exit status | Code condition | Result |
| ----------- | -------------- | ------ |
| `2` | `settings.txt` is missing or invalid | Service exits before detection |
| `3` | `VISION_EDGE_ENABLED` or `VISION_EDGE_MODE` is unsupported | Service exits before detection |
| `4` | `/usr/bin/python3` or `detection_metadata.py` fails its runtime checks | Service exits before scanning the queues |

Only `on` and `off` are accepted for `VISION_EDGE_ENABLED`. Only `metadata`,
`annotated`, `privacy` and `delete` are accepted for `VISION_EDGE_MODE`.

Detection-specific validation is intentionally performed only by the upload
service. An invalid Vision Edge setting does not stop capture from creating new
queued pairs.

An error affecting one pair does not stop the remaining detection scan. The
affected pair remains ineligible for upload unless `delete` recovery completes
its requested removal.

---

## Detection Does Not Complete

Detection runs at the beginning of `phenocam-upload.service`, before upload
configuration and Internet-route checks. Lack of connectivity does not prevent
detection from running.

Inspect one queued metadata file without changing it:

```bash
sudo /usr/bin/python3 \
  /usr/local/lib/phenocam/scripts/detection_metadata.py \
  status --meta /path/to/image.meta
```

| Reported state | Meaning | Manager action |
| -------------- | ------- | -------------- |
| `pending` | No `[detection]` section exists | Applies the current detection configuration |
| `vision` | Vision Edge metadata exists without the two OSCARS fields | Validates the result and attempts to complete the section |
| `off` | Detection was disabled for this pair | Skips detection; pair is upload-ready |
| `ready` | Enabled detection completed and was validated | Skips detection; pair is upload-ready |

An invalid file returns:

```text
error: detection metadata is invalid
```

and a non-zero status. The pair is not uploaded.

### Detection Runtime Is Unavailable

When detection is enabled, the manager requires:

```text
/opt/phenocam-vision-edge-0.2.3/.venv/bin/python
/opt/phenocam-vision-edge-0.2.3/models/yolo26n-phenocam.onnx
/opt/phenocam-vision-edge-0.2.3/models/yolo26n-phenocam.json
```

The Python executable must be executable. The model and receipt must be regular
files and must not be symbolic links.

If these checks fail, the application log contains:

```text
Phenocam Vision Edge runtime is unavailable
```

The affected pending pairs remain queued and are not eligible for upload.

### Detection Metadata Is Rejected

The metadata tool rejects unsafe or inconsistent input, including:

* duplicate `[detection]` sections or duplicate fields;
* an incomplete `filter_enabled` and `filter_mode` pair;
* unsupported filter values;
* incorrect Vision Edge software or model identity;
* inconsistent classes, class counts or `total_count`;
* output filenames that do not match the selected mode;
* a metadata path that is not a regular `.meta` file;
* symbolic links;
* a file replaced while an atomic update is in progress.

The corresponding log message identifies the affected basename. For the exact
field rules, see [Metadata](METADATA.md).

### Detection Output Is Not a Separate File

In `annotated` and `privacy` modes, a positive result atomically replaces the
queued JPEG. A negative result keeps the original JPEG. No permanent image with
a second output name is created.

In `delete` mode, a positive result removes both the JPEG and `.meta` file. If
the JPEG was removed but the `.meta` file remains after an interrupted delete,
the manager removes the remaining metadata file to complete the operation.

---

## Upload Does Not Start

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

This diagnostic checks only whether selected files exist or have non-zero size. It does not validate their effective contents and does not attempt a transfer.

A comment-only configuration file is non-empty and may therefore be reported as present by the diagnostic while remaining disabled in the uploader.

Check the application log:

```bash
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

Check the upload service:

```bash
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
```

Code-level causes include:

* no route to `1.1.1.1`;
* no effective FTP or SFTP configuration;
* invalid `settings.txt`;
* invalid `VISION_EDGE_ENABLED` or `VISION_EDGE_MODE`;
* unavailable detection metadata runtime;
* a queued pair whose detection state is not `off` or `ready`;
* missing SFTP username;
* missing SFTP private key;
* missing `known_hosts`;
* incomplete FTP credentials;
* non-numeric FTP port;
* unsupported `REMOTE_LAYOUT`;
* an existing `upload.lock`.

For configuration formats, see [Configuration](CONFIGURATION.md).

---

## SFTP Upload Fails

Verify that:

* `/etc/phenocam/server.txt` contains at least one destination;
* `SFTP_USER` is set in `settings.txt`;
* `/etc/phenocam/keys/phenocam_key` exists;
* the public key is authorized on every destination;
* every destination fingerprint is present in `/etc/phenocam/known_hosts`;
* `REMOTE_LAYOUT` is `general` or `icos`.

SFTP uses:

```text
BatchMode=yes
StrictHostKeyChecking=yes
```

The uploader does not request an interactive password and does not accept an unknown server key.

Display the public key:

```bash
sudo cat /etc/phenocam/keys/phenocam_key.pub
```

When several SFTP destinations are configured, processing stops at the first destination that returns an upload error. The local pair remains queued.

---

## FTP Upload Fails

`ftp_credentials.txt` must contain at least five effective lines:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

Verify that:

* the five required values are present;
* `FTP_PORT` contains only digits;
* the known example placeholders are not used for `FTP_HOST`, `FTP_PORT`, `FTP_USER` or `FTP_PASS`;
* `REMOTE_LAYOUT` is `general` or `icos`.

The uploader always constructs an `ftp://` URL. Port `22` does not change the protocol to SFTP.

FTP uses passive mode, creates remote directories where supported and applies connection, transfer and retry limits.

---

## Queue Continues to Grow

Queued files are retained when:

* no route to `1.1.1.1` is available;
* no upload method is configured;
* detection is pending or its result is invalid;
* the enabled Vision Edge runtime is unavailable for a pending pair;
* an enabled SFTP or FTP attempt fails;
* one of several enabled destinations fails;
* a final `.meta` file has no matching `.jpg`.

When both FTP and SFTP are enabled, the local pair is removed only after both protocol attempts succeed.

Inspect the queues:

```bash
sudo ls -lah /run/phenocam/queue
sudo ls -lah /var/lib/phenocam/queue
```

The detection manager and uploader process available queues in this order:

```text
USB -> SD -> RAM
```

---

## USB Queue Is Not Used

USB is spillover storage. It is not selected while the RAM queue has at least `RAM_MIN_FREE_MB` available.

During a capture cycle, a USB queue is eligible only when:

* the filesystem is already mounted;
* its mountpoint is below a path listed in `USB_MOUNT_BASES`;
* the mountpoint is writable;
* its usage is below `USB_MAX_USED_PCT`.

The USB event handler does not mount filesystems. It waits three seconds for an external automount process and then searches for a writable mountpoint.

When found, it creates:

```text
<mountpoint>/phenocam_queue
```

The event handler does not load `settings.txt`; without an externally supplied `USB_MOUNT_BASES`, it searches below:

```text
/media
/mnt
```

Inspect current mounts:

```bash
mount
df -h
```

Check application events:

```bash
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

---

## Incomplete or Temporary Files

The uploader discovers queued work from final `.meta` filenames.

A final `.meta` file without its matching `.jpg` is logged as incomplete and remains in place. A `.jpg` without a final `.meta` file is not discovered by the uploader.

Temporary queue files use:

```text
*.jpg.tmp
*.meta.tmp
```

The USB detach handler removes orphan `.tmp` files from the SD queue.

Staging `.jpg` and `.meta` files left by an interrupted eligible capture cycle are removed during the next cycle that passes the acquisition-window check.

---

## Health Values Are Unavailable

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

Temperature is read from:

```text
/sys/class/thermal/thermal_zone0/temp
```

with `vcgencmd measure_temp` as fallback.

Throttling flags and ARM clock frequency require `vcgencmd`. When a value cannot be decoded, the corresponding decoded field is reported as:

```text
nd
```

See [System Health and Thermal Monitoring](THERMAL_MONITORING.md).

---

## Build Information Is Missing

Check:

```bash
cat /usr/local/lib/phenocam/BUILD_INFO
cat /usr/local/lib/phenocam/VERSION
```

`BUILD_INFO` is created during installation and contains:

```text
software_name
software_version
software_branch
software_commit
installed_at
```

When `BUILD_INFO` is unavailable, metadata generation reads `VERSION` when possible and uses `nd` for the unavailable build fields.

---

[Configuration](CONFIGURATION.md) | [Operations](OPERATIONS.md) | [Software Architecture](ARCHITECTURE.md) | [Back to the project README](../../README.md)
