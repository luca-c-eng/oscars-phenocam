# Software Architecture

OSCARS-PHENOCAM is composed of `systemd` units, executable entry points, reusable shell modules, configuration files and three storage queues.

Capture and upload are independent processes. They can run concurrently and use separate lock files.

---

## Deployed Components

| Path                              | Purpose                                     |
| --------------------------------- | ------------------------------------------- |
| `/opt/oscars-phenocam`            | Local copy of the Git repository            |
| `/usr/local/lib/phenocam/bin`     | Executable entry points and diagnostics     |
| `/usr/local/lib/phenocam/scripts` | Capture, metadata, storage and upload logic |
| `/usr/local/lib/phenocam/docs`    | Installed documentation                     |
| `/etc/phenocam`                   | Station and upload configuration            |
| `/run/phenocam`                   | Volatile runtime storage and locks          |
| `/var/lib/phenocam/queue`         | Persistent SD fallback queue                |
| `/var/log/phenocam`               | Application log directory                   |

Runtime services use the dedicated `phenocam` system user. The installer adds this user to the `video` group.

---

## Runtime Layers

| Layer         | Components              | Responsibility                                                 |
| ------------- | ----------------------- | -------------------------------------------------------------- |
| Scheduling    | `systemd` timers        | Requests capture, upload and startup-test operations           |
| Execution     | `software/bin/*.sh`     | Provides locked entry points and diagnostics                   |
| Processing    | `software/scripts/*.sh` | Implements acquisition, metadata, storage selection and upload |
| Configuration | `/etc/phenocam/*`       | Supplies station and remote-destination values                 |
| Storage       | RAM, USB and SD queues  | Retains image and metadata pairs                               |

---

## Boot Sequence

`phenocam-init.service` executes:

```text
/usr/local/lib/phenocam/bin/phenocam-init-ramdisk.sh
```

The script:

1. reads total system memory;
2. calculates a `tmpfs` size equal to 20% of total memory;
3. applies a minimum size of 50 MB;
4. writes the numeric `phenocam` UID and GID into `run-phenocam.mount`;
5. starts the mount when it is inactive;
6. restarts it when its options changed and no queued JPEG or metadata files are present;
7. creates `/run/phenocam/queue` and `/run/phenocam/staging`.

If the active mount contains `.jpg` or `.meta` files, it is not restarted when its options change.

`phenocam-startup-cycle.timer` requests one startup test approximately two minutes after boot. The test calls capture first and upload second. Capture may complete without producing an image when the station is outside its acquisition window.

---

## Capture Flow

```mermaid
flowchart TD
    A["Capture timer"] --> B["Capture service"]
    B --> C["Acquire capture.lock"]
    C --> D{"Inside acquisition window?"}
    D -- No --> E["Complete without image"]
    D -- Yes --> F["Clean staging"]
    F --> G["Capture JPEG"]
    G --> H["Generate META"]
    H --> I["Select destination queue"]
```

The capture service executes:

```text
phenocam-capture.sh
  └─ cycle.sh
      ├─ config_read.sh
      ├─ capture_vis.sh
      ├─ meta_build.sh
      ├─ storage_manager.sh
      └─ queue_manager.sh
```

### Capture Sequence

1. `phenocam-capture.sh` acquires `/run/phenocam/capture.lock`.
2. `cycle.sh` reads `/etc/phenocam/settings.txt`.
3. The current station hour is compared with the acquisition window.
4. If the station is outside the window, the cycle returns successfully without modifying staging.
5. During an eligible cycle, existing `.jpg` and `.meta` files in staging are removed.
6. `capture_vis.sh` creates the JPEG.
7. `meta_build.sh` creates its `.meta` sidecar.
8. `queue_manager.sh` attempts to move the completed pair into a queue.

Image acquisition uses `rpicam-still` when available and otherwise uses `libcamera-still`.

---

## Queue Selection

```mermaid
flowchart TD
    A["Completed pair"] --> B{"RAM free space sufficient?"}
    B -- Yes --> C["RAM queue"]
    B -- No --> D{"Writable USB below limit?"}
    D -- Yes --> E["USB queue"]
    D -- No --> F{"SD below limit?"}
    F -- Yes --> G["SD queue"]
    F -- No --> H["Remove staged pair"]
```

Queue selection follows these rules:

1. use RAM when free space is at or above `RAM_MIN_FREE_MB`;
2. otherwise locate the first mounted and writable filesystem below `USB_MOUNT_BASES`;
3. use its USB queue when usage is below `USB_MAX_USED_PCT`;
4. otherwise attempt to use the SD queue;
5. if SD usage is at or above `SD_MAX_USED_PCT`, remove the captured pair from staging and return successfully without queuing it.

| Queue | Path                          |
| ----- | ----------------------------- |
| RAM   | `/run/phenocam/queue`         |
| USB   | `<mountpoint>/phenocam_queue` |
| SD    | `/var/lib/phenocam/queue`     |

The RAM queue is volatile. USB and SD queues reside outside the RAM-backed filesystem.

`SD_MAX_USED_PCT` is checked only when SD fallback is required.

---

## Queue Pair Publication

The JPEG and metadata files are first generated in:

```text
/run/phenocam/staging
```

Queue insertion moves them to temporary destination names:

```text
<basename>.jpg.tmp
<basename>.meta.tmp
```

The files are then renamed in this order:

1. JPEG temporary file to final `.jpg`;
2. metadata temporary file to final `.meta`.

The uploader discovers work by listing final `.meta` files. Consequently, a visible final metadata file has a corresponding final JPEG at the time of publication.

The JPEG and metadata files are not published by one filesystem operation. The final `.meta` filename acts as the signal that the pair is available for upload.

---

## Upload Flow

```mermaid
flowchart TD
    A["Upload timer"] --> B["Upload service"]
    B --> C["Acquire upload.lock"]
    C --> D{"Configuration and route available?"}
    D -- No --> E["Retain queued files"]
    D -- Yes --> F["Process USB, SD and RAM"]
    F --> G["Attempt enabled uploads"]
    G --> H{"Every attempt succeeded?"}
    H -- Yes --> I["Remove local pair"]
    H -- No --> J["Retain pair for retry"]
```

The upload service executes:

```text
phenocam-upload.sh
  ├─ config_read.sh
  ├─ net_check.sh
  ├─ storage_manager.sh
  ├─ upload_sftp.sh
  ├─ upload_ftp.sh
  └─ uploader_daemon.sh
```

### Upload Sequence

1. `phenocam-upload.sh` acquires `/run/phenocam/upload.lock`.

2. The current settings are read.

3. SFTP and FTP activation is determined from their configuration files.

4. Internet-route availability is checked.

5. Queues are processed in this order:

   ```text
   USB → SD → RAM
   ```

6. Queue work is discovered from final `.meta` filenames.

7. A pair is processed only when its matching `.jpg` file exists.

8. SFTP is attempted first when enabled.

9. FTP is then attempted when enabled.

10. The local pair is removed only when every enabled upload attempt succeeds.

No per-destination delivery state is stored. If one destination succeeds and another fails, the retained pair is offered to all enabled destinations again during the next upload cycle.

---

## Failure Behaviour

| Condition                             | Result                                                              |
| ------------------------------------- | ------------------------------------------------------------------- |
| Invalid `settings.txt`                | Requested service fails                                             |
| Outside acquisition window            | Capture cycle completes without producing files                     |
| Camera failure                        | Capture service fails                                               |
| Metadata failure                      | Capture service fails                                               |
| SD fallback threshold reached         | Captured pair is removed and the cycle completes without queuing it |
| No upload method configured           | Upload completes without removing queued files                      |
| No internet route at upload start     | Upload is postponed and queued files remain                         |
| Network lost while processing a pair  | Pair remains queued and upload returns a non-zero result            |
| Upload target failure                 | Pair remains queued for another cycle                               |
| Final `.meta` without matching `.jpg` | Incomplete pair is ignored and remains in place                     |
| Existing operation lock               | Duplicate operation fails immediately                               |

Files left in staging after a failed eligible capture cycle are removed at the beginning of the next cycle that is inside the acquisition window.

---

## USB Event Handling

The installed `udev` rule starts handlers for USB block-device insertion and removal.

The handlers do not read `/etc/phenocam/settings.txt`. They use `USB_MOUNT_BASES` only if it is already present in their environment; otherwise they scan:

```text
/media
/mnt
```

On insertion, the attach handler:

1. waits three seconds for an external automount process;
2. searches for the first mounted and writable filesystem below the scanned paths;
3. creates:

   ```text
   <mountpoint>/phenocam_queue
   ```

The handler does not mount the filesystem and does not enforce a filesystem type.

On removal, the detach handler:

1. scans the same mount locations;
2. attempts a lazy unmount when a registered mountpoint is no longer accessible;
3. removes orphan `.tmp` files from the SD queue.

Regular capture and upload processes read `USB_MOUNT_BASES` from `settings.txt`.

---

## Manual Wrapper

`phenocam-run.sh` requests one capture followed by one upload.

Because the wrapper uses `set -e`, upload is not executed if the capture command returns a non-zero status.

No installed `systemd` unit calls this wrapper in `dev/v1.7.0`. Regular operation uses the dedicated capture, upload and startup-cycle services.

---

[Configuration](CONFIGURATION.md) · [Operations](OPERATIONS.md) · [Back to the project README](../../README.md)
