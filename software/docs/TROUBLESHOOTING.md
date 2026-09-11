# Troubleshooting

This guide covers failures and unexpected behaviour directly handled or reported by OSCARS-PHENOCAM `dev/v1.7.0`.

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

List the next scheduled executions:

```bash
systemctl list-timers 'phenocam-*' --all
```

Capture and upload services are `oneshot` units. After a successful execution, an `inactive (dead)` state is normal. Their timers should remain active.

---

## Installation Stops

### Installer Run as Root

The installer refuses to run when the current user is `root`.

Run it as a regular user with `sudo` privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/refs/heads/dev/v1.7.0/install.sh | bash
```

Do not prefix this command with `sudo`.

### No Network Route

The installer requires:

```bash
ip route get 1.1.1.1
```

to succeed. If no route is available, installation stops before packages and repository files are downloaded.

Inspect the network state with:

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

The installer installs `git` and `libimage-exiftool-perl`, but expects the commands above to be provided by the operating system.

---

## RAM Initialization Fails

Inspect the service:

```bash
sudo systemctl status phenocam-init.service
sudo journalctl -u phenocam-init.service -n 120 --no-pager
```

The initialization script fails when:

* `/etc/systemd/system/run-phenocam.mount` is missing;
* the `phenocam` system user does not exist.

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

The diagnostic uses `rpicam-hello --list-cameras`, with `libcamera-hello` as fallback.

If neither command exists, the diagnostic terminates with an error.

After the installer has requested camera activation, a reboot may be required:

```bash
sudo reboot
```

---

## No Image Is Captured

Inspect the capture service and log:

```bash
sudo systemctl status phenocam-capture.service
sudo journalctl -u phenocam-capture.service -n 100 --no-pager
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

Possible code-level causes are:

| Condition                                  | Behaviour                                                   |
| ------------------------------------------ | ----------------------------------------------------------- |
| Outside the configured capture window      | Service completes without creating an image                 |
| Invalid `settings.txt`                     | Capture service fails                                       |
| Camera command unavailable or unsuccessful | Capture service fails                                       |
| Camera timeout reached                     | Capture command is terminated                               |
| `exiftool` unavailable                     | Metadata generation fails                                   |
| SD usage threshold reached                 | Captured staging files are removed and the cycle is skipped |
| `capture.lock` already held                | Duplicate capture exits immediately                         |
| Timer event missed while powered off       | Event is not replayed                                       |

The capture timer uses `Persistent=false`.

### Startup Test Succeeds but Creates No Image

The startup cycle calls the standard capture entry point. The same acquisition-window check is applied.

A successful startup cycle outside the configured window may therefore complete without creating a new image.

---

## Capture or Upload Reports a Lock Error

The software uses:

```text
/run/phenocam/capture.lock
/run/phenocam/upload.lock
```

Locks are non-blocking. A duplicate operation fails when another instance of the same operation is already running.

Check the corresponding service:

```bash
systemctl status phenocam-capture.service
systemctl status phenocam-upload.service
```

A lock file may remain on disk after execution. Its presence alone does not mean that the lock is active.

---

## Upload Does Not Start

Run the prerequisite diagnostic:

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

This command only checks whether expected files exist or are non-empty. It does not validate their effective contents or attempt a transfer.

A comment-only `ftp_credentials.txt`, for example, is non-empty but does not enable FTP in the uploader.

Check the application log:

```bash
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

Check the upload service:

```bash
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
```

Possible causes are:

* no internet route;
* no effective FTP or SFTP configuration;
* invalid `settings.txt`;
* missing SFTP username;
* missing private key;
* missing `known_hosts`;
* invalid FTP credential structure;
* non-numeric FTP port;
* unsupported `REMOTE_LAYOUT`;
* an upload operation already holding `upload.lock`.

For the required file formats, see [Configuration](CONFIGURATION.md).

---

## SFTP Upload Fails

Verify that:

1. `/etc/phenocam/server.txt` contains at least one effective hostname or IP;
2. `SFTP_USER` is configured in `settings.txt`;
3. `/etc/phenocam/keys/phenocam_key` exists;
4. the public key is authorized on the remote server;
5. every server fingerprint is present in `/etc/phenocam/known_hosts`;
6. `REMOTE_LAYOUT` is `general` or `icos`.

SFTP uses:

```text
BatchMode=yes
StrictHostKeyChecking=yes
```

It does not request an interactive password or accept an unknown server key.

Display the public key with:

```bash
sudo cat /etc/phenocam/keys/phenocam_key.pub
```

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

* none of the values is empty;
* `FTP_PORT` is numeric;
* placeholder values have been replaced;
* `REMOTE_LAYOUT` is `general` or `icos`.

The FTP uploader always builds an `ftp://` URL. Port `22` does not switch the protocol to SFTP.

---

## Queue Continues to Grow

Queued files are retained when:

* no internet route is available;
* no upload protocol is configured;
* an FTP or SFTP upload fails;
* one of the enabled protocols fails;
* a pair is incomplete.

When both FTP and SFTP are enabled, the local pair is removed only after both protocols succeed.

Inspect the queues:

```bash
sudo ls -lah /run/phenocam/queue
sudo ls -lah /var/lib/phenocam/queue
```

The uploader processes USB first, then SD, then RAM.

---

## USB Queue Is Not Used

USB storage is spillover storage. It is not used while the RAM queue still has at least `RAM_MIN_FREE_MB` available.

The software uses a USB queue only when:

* the filesystem is already mounted;
* its mountpoint is below a path listed in `USB_MOUNT_BASES`;
* the mountpoint is writable;
* its usage is below `USB_MAX_USED_PCT`.

The USB handler does not mount the filesystem. It waits for an external automount process and then creates:

```text
<mountpoint>/phenocam_queue
```

Inspect mounts with:

```bash
mount
df -h
```

Check USB-related events in:

```bash
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

---

## Incomplete or Temporary Files

The uploader discovers pairs from final `.meta` filenames. A `.meta` file without the matching `.jpg` is logged as an incomplete pair and remains in the queue.

Temporary queue files use:

```text
*.jpg.tmp
*.meta.tmp
```

Staging `.jpg` and `.meta` files left by a failed capture are removed at the beginning of the next capture cycle.

The USB detach handler removes orphan `.tmp` files from the SD queue.

---

## Health Values Are Unavailable

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

Temperature is read from the thermal sysfs interface or `vcgencmd`.

Throttling flags and ARM clock frequency require `vcgencmd`. When a value cannot be obtained or decoded, the corresponding output is `nd`.

See [System Health and Thermal Monitoring](THERMAL_MONITORING.md).

---

## Build Information Is Missing

Check:

```bash
cat /usr/local/lib/phenocam/BUILD_INFO
cat /usr/local/lib/phenocam/VERSION
```

`BUILD_INFO` is created during installation and contains the software name, version, branch, commit, and installation timestamp.

When it is unavailable, generated metadata falls back to `VERSION` and uses `nd` for unavailable build fields.

---

[Configuration](CONFIGURATION.md) · [Operations](OPERATIONS.md) · [Software Architecture](ARCHITECTURE.md) · [Back to the project README](../../README.md)
