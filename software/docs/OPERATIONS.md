# Operations

This guide describes routine operation of the ICOS-dedicated
OSCARS-PHENOCAM `dev/v0.1.0` branch.

## Runtime Units

| Unit | Purpose |
| --- | --- |
| `phenocam-init.service` | Prepares RAM-backed runtime storage |
| `phenocam-capture.timer` | Requests regular captures using the persistent offset |
| `phenocam-upload.timer` | Runs screening, daily packaging and ICOS upload one minute later |
| `phenocam-startup-cycle.service` | Manual diagnostic capture followed by queue processing; not scheduled automatically |

Inspect timers with:

```bash
systemctl list-timers 'phenocam-*' --all
```

Apply timing changes with:

```bash
sudo /usr/local/lib/phenocam/bin/phenocam-configure-schedule.sh
```

Missed timer events are not replayed after downtime. This prevents boot from
creating an image outside the station-specific minute sequence.

## Manual Execution

Request one capture cycle:

```bash
sudo systemctl start phenocam-capture.service
```

Request the explicit capture-plus-upload diagnostic when an additional,
off-schedule test image is acceptable:

```bash
sudo systemctl start phenocam-startup-cycle.service
```

Process detection, close eligible days and attempt outbox uploads:

```bash
sudo systemctl start phenocam-upload.service
```

Inspect the result:

```bash
sudo systemctl status phenocam-capture.service phenocam-upload.service
sudo tail -n 100 /var/log/phenocam/phenocam.log
```

## Storage

| Location | Use |
| --- | --- |
| `/run/phenocam/queue` | Primary volatile queue |
| `<mountpoint>/phenocam_queue` | USB spillover queue |
| `/var/lib/phenocam/queue` | Persistent SD fallback |
| `/var/lib/phenocam/icos-outbox` | ZIPs, JSON packages, manifests and retry state |
| `/var/lib/phenocam/icos-receipts` | Completed upload receipts |

An outbox ZIP is immutable. Do not edit its ZIP or JSON package. Network and
server failures leave it available for a later cycle.

A file ending in `.blocked` records an HTTP 4xx or local validation error.
Inspect the message and correct the corresponding configuration. Remove only
that product's `.blocked` marker before requesting a retry.

```bash
sudo ls -lah /var/lib/phenocam/icos-outbox
sudo sed -n '1,120p' /var/lib/phenocam/icos-outbox/<product>.zip.blocked
```

## Verify Configuration

Display the non-secret settings by effective position:

```bash
sudo awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  { print ++n ": " $0 }
' /etc/phenocam/settings.txt
```

Do not print the credentials file in shared terminals or support logs.

## Receipts

The receipt is written only after the data-service PUT succeeds. It records the
environment, ZIP name, SHA-256, completion time, object URL and service
responses. It does not contain the account password.

```bash
sudo ls -lah /var/lib/phenocam/icos-receipts
```

Source image/metadata pairs are deleted only after this confirmation and a
successful comparison against their packaging manifest.

## Safe Change from Staging to Production

1. Complete an authenticated end-to-end upload in staging.
2. Confirm the object and metadata with ICOS/Carbon Portal staff.
3. Complete or otherwise resolve the staging outbox.
4. Set field 29 to `production`.
5. Install the production credentials assigned to the station.
6. Run the upload service and inspect the receipt and log.

Changing the environment does not rewrite products already prepared in the
outbox. This prevents an archive registered in one environment from being
silently submitted to another.

[Configuration](CONFIGURATION.md) | [Architecture](ARCHITECTURE.md) | [Project README](../../README.md)
