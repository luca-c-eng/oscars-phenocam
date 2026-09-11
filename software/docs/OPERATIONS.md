# Operations

This guide covers the routine operation of OSCARS-PHENOCAM `dev/v1.7.0`.

For installation and configuration, see:

* [Clean Installation](CLEAN_INSTALL.md)
* [Configuration](CONFIGURATION.md)

---

## Runtime Units

| Unit                             | Purpose                                           |
| -------------------------------- | ------------------------------------------------- |
| `phenocam-init.service`          | Prepares the RAM-backed runtime storage           |
| `run-phenocam.mount`             | Mounts the `/run/phenocam` `tmpfs`                |
| `phenocam-startup-cycle.timer`   | Schedules one startup test after boot             |
| `phenocam-startup-cycle.service` | Requests one capture followed by one upload cycle |
| `phenocam-capture.timer`         | Schedules regular capture cycles                  |
| `phenocam-capture.service`       | Runs one image acquisition cycle                  |
| `phenocam-upload.timer`          | Schedules regular upload cycles                   |
| `phenocam-upload.service`        | Processes all configured queues                   |

Capture and upload run as separate `systemd` services.

---

## Default Schedule

| Timer                          | Default schedule                                                         |
| ------------------------------ | ------------------------------------------------------------------------ |
| `phenocam-startup-cycle.timer` | Once, approximately 2 minutes after boot                                 |
| `phenocam-capture.timer`       | At minutes `00` and `30` of every hour                                   |
| `phenocam-upload.timer`        | Approximately 3 minutes after boot, then 9 minutes after each activation |

The timers use `Persistent=false`. Missed executions are not replayed after the system has been offline.

The startup cycle invokes capture and then upload. If the station is outside its configured acquisition window, the capture command completes without creating an image.

---

## Check Runtime Status

Check the main units:

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

Check whether the timers are enabled at boot:

```bash
systemctl is-enabled \
  phenocam-startup-cycle.timer \
  phenocam-capture.timer \
  phenocam-upload.timer
```

---

## Manual Execution

### Capture One Image

```bash
sudo systemctl start phenocam-capture.service
```

The capture is skipped when the current station hour is outside the configured acquisition window.

Check the result:

```bash
sudo systemctl status phenocam-capture.service
```

### Process the Upload Queues

```bash
sudo systemctl start phenocam-upload.service
```

Check the result:

```bash
sudo systemctl status phenocam-upload.service
```

If no internet route or no upload destination is available, queued files are retained.

### Run the Startup Cycle

```bash
sudo systemctl start phenocam-startup-cycle.service
```

This requests one capture cycle followed by one upload cycle.

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

Disabling the timers does not delete queued files.

---

## Storage Queues

| Queue   | Path                          | Purpose                                 |
| ------- | ----------------------------- | --------------------------------------- |
| RAM     | `/run/phenocam/queue`         | Primary, volatile queue                 |
| USB     | `<mountpoint>/phenocam_queue` | Spillover when RAM free space is low    |
| SD card | `/var/lib/phenocam/queue`     | Final persistent fallback               |
| Staging | `/run/phenocam/staging`       | Temporary capture and metadata creation |

The uploader processes queues in this order:

1. USB
2. SD card
3. RAM

Only complete `.jpg` and `.meta` pairs are uploaded.

Check the RAM-backed storage:

```bash
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
```

Check the SD queue:

```bash
sudo ls -lah /var/lib/phenocam/queue
```

Because the RAM queue is volatile, its contents are lost when the `tmpfs` is unmounted or the system powers off.

---

## Concurrency Protection

Capture and upload use separate non-blocking lock files:

```text
/run/phenocam/capture.lock
/run/phenocam/upload.lock
```

A second instance of the same operation exits when its lock is already held.

Image and metadata pairs are moved into a queue through temporary files and renamed only after both files are ready.

---

## USB Storage

USB insertion and removal events are handled by the installed `udev` rule.

After a writable filesystem is mounted below a configured USB base path, the software creates:

```text
<mountpoint>/phenocam_queue
```

USB storage is used only when the RAM queue falls below its configured free-space threshold.

If the USB queue exceeds its configured usage threshold, new pairs fall back to the SD queue.

Removing the USB device causes subsequent captures to use the available fallback queue. An inaccessible stale mount may be released through a lazy unmount.

---

## Logs

Application events are written to:

```text
/var/log/phenocam/phenocam.log
```

View recent events:

```bash
sudo tail -n 50 /var/log/phenocam/phenocam.log
```

Follow the log in real time:

```bash
sudo tail -f /var/log/phenocam/phenocam.log
```

The installed log rotation policy rotates the file at `1 MB`, retains seven rotations, and compresses rotated logs.

### systemd Journal

Capture:

```bash
sudo journalctl -u phenocam-capture.service -n 100 --no-pager
```

Upload:

```bash
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
```

Startup cycle:

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

Lists cameras detected through `rpicam-hello` or `libcamera-hello`.

### Network

```bash
sudo /usr/local/lib/phenocam/bin/diag_net.sh
```

Displays network interfaces, IPv4 addresses, and routes.

### RAM-backed Storage

```bash
sudo /usr/local/lib/phenocam/bin/diag_ramdisk.sh
```

Displays `tmpfs` mounts, `/run` usage, and `/run/phenocam` contents.

### Upload Prerequisites

```bash
sudo /usr/local/lib/phenocam/bin/diag_upload.sh
```

Checks whether the expected upload files and SSH key exist. It does not perform a transfer or fully validate their effective contents.

### System Health

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

Displays:

* SoC temperature;
* ARM clock frequency;
* current undervoltage and throttling flags;
* throttling conditions recorded since boot.

### Installed Build

```bash
cat /usr/local/lib/phenocam/BUILD_INFO
```

Displays the installed software version, branch, commit, and installation timestamp.

---

[Configuration](CONFIGURATION.md) · [Back to the project README](../../README.md)

