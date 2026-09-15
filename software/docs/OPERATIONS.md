# Operations

This guide describes the routine operation of OSCARS-PHENOCAM `dev/v1.7.0`.

For initial setup, see:

* [Clean Installation](CLEAN_INSTALL.md)
* [Configuration](CONFIGURATION.md)

---

## Runtime Units

| Unit                             | Purpose                                 |
| -------------------------------- | --------------------------------------- |
| `phenocam-init.service`          | Prepares the RAM-backed runtime storage |
| `run-phenocam.mount`             | Mounts the `/run/phenocam` `tmpfs`      |
| `phenocam-startup-cycle.timer`   | Requests one startup test after boot    |
| `phenocam-startup-cycle.service` | Requests capture followed by upload     |
| `phenocam-capture.timer`         | Schedules regular capture cycles        |
| `phenocam-capture.service`       | Runs one acquisition cycle              |
| `phenocam-upload.timer`          | Schedules regular upload cycles         |
| `phenocam-upload.service`        | Processes the configured queues         |

Capture and upload use separate services and separate lock files.

---

## Default Schedule

| Timer                          | Code-defined schedule                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------------- |
| `phenocam-startup-cycle.timer` | Once, approximately two minutes after boot                                            |
| `phenocam-capture.timer`       | At minutes `00` and `30` of every hour in UTC                                         |
| `phenocam-upload.timer`        | Approximately three minutes after boot, then nine minutes after each timer activation |

All three timers use:

```ini
Persistent=false
```

Executions missed while the system is powered off are not replayed.

The capture timer schedule is defined directly in its `systemd` unit. `INTERVAL_MIN` in `settings.txt` does not change it.

---

## Check Runtime Status

Check the principal units:

```bash
sudo systemctl status \
  phenocam-init.service \
  run-phenocam.mount \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

List scheduled executions:

```bash
systemctl list-timers 'phenocam-*' --all
```

Check whether timers are enabled at boot:

```bash
systemctl is-enabled \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Capture, upload and startup-cycle services are `oneshot` units. After they finish successfully, `inactive (dead)` is a normal state.

---

## Manual Execution

### Request One Capture Cycle

```bash
sudo systemctl start phenocam-capture.service
```

The service:

1. reads the current settings;
2. checks the acquisition window;
3. captures a JPEG when the station is inside the window;
4. generates metadata;
5. attempts to queue the pair.

No image is created when the station is outside the acquisition window.

If SD fallback is required and SD usage is at or above `SD_MAX_USED_PCT`, the generated pair is removed and the service completes without queuing it.

Check the result:

```bash
sudo systemctl status phenocam-capture.service
```

### Process Upload Queues

```bash
sudo systemctl start phenocam-upload.service
```

The service reads the current configuration and processes USB, SD and RAM queues.

If no route or no upload method is available at the start of the cycle, queued files remain in place.

Check the result:

```bash
sudo systemctl status phenocam-upload.service
```

### Run the Startup Test Cycle

```bash
sudo systemctl start phenocam-startup-cycle.service
```

The service requests capture first and upload second.

If capture returns a non-zero status, the startup service exits without executing upload. A capture outside the acquisition window returns successfully, so upload is still requested.

---

## Enable or Disable Automatic Operation

Enable and start all timers:

```bash
sudo systemctl enable --now \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Stop and disable all timers:

```bash
sudo systemctl disable --now \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

Disabling timers does not delete queued files.

---

## Storage Queues

| Queue   | Path                          | Use                                                  |
| ------- | ----------------------------- | ---------------------------------------------------- |
| RAM     | `/run/phenocam/queue`         | Primary volatile queue                               |
| USB     | `<mountpoint>/phenocam_queue` | Spillover when RAM free space is below its threshold |
| SD      | `/var/lib/phenocam/queue`     | Persistent fallback                                  |
| Staging | `/run/phenocam/staging`       | JPEG and metadata generation before queue selection  |

The uploader processes available queues in this order:

```text
USB → SD → RAM
```

Queue work is discovered from final `.meta` files. A pair is uploaded only when the corresponding final `.jpg` exists.

Check RAM-backed storage:

```bash
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
```

Check the SD queue:

```bash
sudo ls -lah /var/lib/phenocam/queue
```

The RAM queue and staging directory are located on `tmpfs`. Their contents are lost when the mount is unmounted or the system powers off.

---

## Concurrency Protection

Capture and upload use separate non-blocking locks:

```text
/run/phenocam/capture.lock
/run/phenocam/upload.lock
```

A second instance of the same operation exits with an error while the corresponding lock is held.

The presence of a lock file alone does not indicate that the lock is active.

---

## Queue Pair Publication

JPEG and metadata files are generated in staging before queue selection.

Queue insertion uses:

```text
<basename>.jpg.tmp
<basename>.meta.tmp
```

The JPEG is renamed to its final name first. The metadata file is renamed last and acts as the signal used by the uploader to discover the pair.

For the complete sequence, see [Software Architecture](ARCHITECTURE.md).

---

## USB Storage

USB storage is considered only when the RAM queue has less than `RAM_MIN_FREE_MB` available.

During regular capture and upload cycles, mountpoints are searched below the paths configured in `USB_MOUNT_BASES`.

A USB queue is eligible when:

* the filesystem is already mounted;
* the mountpoint is writable;
* its usage is below `USB_MAX_USED_PCT`.

If no eligible USB queue exists, new pairs fall back to the SD queue.

### USB Event Handlers

The installed `udev` rule starts separate attach and detach handlers.

The attach handler:

1. waits three seconds for an external automount process;
2. searches for the first mounted and writable filesystem;
3. creates `<mountpoint>/phenocam_queue`.

The handler does not mount the filesystem and does not validate its filesystem type.

The USB handlers do not load `settings.txt`. Unless `USB_MOUNT_BASES` is supplied through their environment, they scan:

```text
/media
/mnt
```

The detach handler can perform a lazy unmount when a registered mountpoint is no longer accessible. It also removes orphan `.tmp` files from the SD queue.

---

## Application Log

Application events are appended to:

```text
/var/log/phenocam/phenocam.log
```

View recent events:

```bash
sudo tail -n 50 /var/log/phenocam/phenocam.log
```

Follow the log:

```bash
sudo tail -f /var/log/phenocam/phenocam.log
```

The installed log-rotation configuration:

* rotates the file when it reaches `1M`;
* retains seven rotations;
* compresses rotated logs;
* delays compression of the most recent rotated file;
* ignores missing and empty logs.

---

## systemd Journal

Capture service:

```bash
sudo journalctl -u phenocam-capture.service -n 100 --no-pager
```

Upload service:

```bash
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
```

Startup test:

```bash
sudo journalctl -u phenocam-startup-cycle.service -n 100 --no-pager
```

RAM initialization:

```bash
sudo journalctl -u phenocam-init.service -n 100 --no-pager
```

---

## Diagnostics

### Camera

```bash
sudo /usr/local/lib/phenocam/bin/diag_camera.sh
```

Lists cameras using `rpicam-hello --list-cameras`, with `libcamera-hello` as fallback.

### Network

```bash
sudo /usr/local/lib/phenocam/bin/diag_net.sh
```

Displays network links, IPv4 addresses and the routing table.

### RAM-Backed Storage

```bash
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
```

Displays `tmpfs` mounts, `/run` usage and `/run/phenocam` contents.

### Upload Prerequisites

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

Checks whether selected upload files exist or have non-zero size. It does not validate their complete effective content and does not perform a transfer.

### System Health

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

Displays temperature, ARM clock, the raw throttling value and decoded flag fields.

### Installed Build

```bash
cat /usr/local/lib/phenocam/BUILD_INFO
```

Displays the software name, version, branch, commit and installation timestamp recorded by the installer.

---

[Configuration](CONFIGURATION.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Back to the project README](../../README.md)
