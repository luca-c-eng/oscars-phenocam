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

No image is created when the station is outside the acquisition wind
