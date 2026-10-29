# Troubleshooting

## First Checks

```bash
sudo systemctl status phenocam-capture.service phenocam-upload.service
sudo journalctl -u phenocam-upload.service -n 100 --no-pager
sudo tail -n 100 /var/log/phenocam/phenocam.log
systemctl list-timers 'phenocam-*' --all
```

Inspect queue and outbox state:

```bash
sudo find /run/phenocam/queue /var/lib/phenocam/queue \
  /var/lib/phenocam/icos-outbox -maxdepth 1 -type f -printf '%p\n'
```

## Upload Does Not Start

Check that effective settings fields 29–34 exist and that fields 30–33 are not
`nd`:

```bash
sudo awk '
  /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
  { print ++n ": " $0 }
' /etc/phenocam/settings.txt
```

The upload manager deliberately retains data when any identity value is
missing, the station code is invalid, the environment is unsupported or the
station/instrument URI is not canonical.

## Credentials Are Rejected

`/etc/phenocam/cp_credentials.txt` must contain exactly two non-empty lines:
the account email on line 1 and password on line 2. It must be a regular file
readable by the `phenocam` group:

```bash
sudo chown root:phenocam /etc/phenocam/cp_credentials.txt
sudo chmod 640 /etc/phenocam/cp_credentials.txt
```

Do not paste its contents into logs or support messages. Confirm that the
account is authorized for the selected `staging` or `production` environment.

## A Product Is Blocked

HTTP 4xx responses and local validation errors create a `.blocked` file:

```bash
sudo ls -1 /var/lib/phenocam/icos-outbox/*.blocked
sudo sed -n '1,120p' /var/lib/phenocam/icos-outbox/<product>.zip.blocked
```

Correct the reported identity, metadata or authorization problem. Then remove
only the matching `.blocked` marker and restart the upload service. Do not edit
the ZIP or its JSON package.

## Product Belongs to Another Environment

Every product records the environment in which it was prepared. If
`CP_ENVIRONMENT` changes while products remain in the outbox, those products
are retained and not submitted to the new endpoint. Restore the original
environment and complete them, or resolve them explicitly before switching.

## Queue Continues to Grow

Common causes are:

- ICOS identity fields are still placeholders;
- credentials are absent;
- detection is incomplete or invalid;
- one JPEG lacks its matching `.meta` file;
- the current day has not yet closed;
- no Internet route is available;
- a retryable Carbon Portal response was received.

The system never deletes a pair merely because upload is unavailable.

## Schedule Is Not Updated

After changing `INTERVAL_MIN` or `CAPTURE_MINUTE`, run:

```bash
sudo /usr/local/lib/phenocam/bin/phenocam-configure-schedule.sh
systemctl list-timers 'phenocam-capture*' 'phenocam-upload*' --all
```

`CAPTURE_MINUTE` must be non-negative and smaller than `INTERVAL_MIN`.

## Source Cleanup Is Refused

After a successful PUT, the manager compares every remaining source file with
the SHA-256 manifest created during packaging. If a file changed, it refuses
cleanup and retains the daily product state. Investigate the changed queue file
instead of deleting the manifest.

[Configuration](CONFIGURATION.md) | [Operations](OPERATIONS.md) | [Architecture](ARCHITECTURE.md)
