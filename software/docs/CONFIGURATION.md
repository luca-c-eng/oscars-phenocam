# Configuration

OSCARS-PHENOCAM uses two protected configuration files:

| Path | Contents | Owner and mode |
| --- | --- | --- |
| `/etc/phenocam/settings.txt` | Non-secret station, capture and ICOS values | `root:phenocam`, `640` |
| `/etc/phenocam/cp_credentials.txt` | Station account email and password | `root:phenocam`, `640` |

## Main Settings

`settings.txt` is positional: blank and comment lines are ignored, and each
effective value must retain its position.

| Pos. | Variable | Initial value | Effective behaviour |
| ---: | --- | --- | --- |
| 1 | `SITENAME` | `mysite` | ICOS station code used in pair and ZIP filenames |
| 2 | `UTC_OFFSET` | `+1` | Fixed station offset; daylight saving is not applied |
| 3 | `TZ_LABEL` | `UTC+1` | Retained position; regenerated from `UTC_OFFSET` |
| 4 | `START_HOUR` | `6` | Acquisition-window start, inclusive |
| 5 | `END_HOUR` | `22` | Acquisition-window end, exclusive |
| 6 | `INTERVAL_MIN` | `30` | 5, 10, 15, 20, 30 or 60 minutes |
| 7 | `IFACE` | `auto` | Explicit interface or automatic route selection |
| 8 | legacy remote user | `phenocam` | Reserved positional field; unused in the ICOS build |
| 9 | `NET_MODE` | `auto` | `auto`, `ethernet` or `wifi` |
| 10 | `RAM_MIN_FREE_MB` | `20` | RAM queue free-space threshold |
| 11 | `SD_MAX_USED_PCT` | `80` | SD fallback usage threshold |
| 12 | `USB_MOUNT_BASES` | `/media:/mnt` | Locations scanned for mounted USB storage |
| 13 | `USB_MAX_USED_PCT` | `90` | USB usage threshold |
| 14 | `REMOTE_LAYOUT` | `icos` | Must remain `icos` in this dedicated build |
| 15–20 | site metadata | `nd` | Existing sidecar metadata fields |
| 21 | `BOARD` | detected value | Board identifier |
| 22 | `CAMERA_MODEL` | `imx708` | Camera identifier |
| 23 | `CAPTURE_TIMEOUT` | `30000` | Camera warm-up time in milliseconds |
| 24 | `VISION_EDGE_ENABLED` | `off` | `on` or `off` |
| 25 | `VISION_EDGE_MODE` | `metadata` | `metadata`, `annotated` or `delete` |
| 26 | `IMAGE_WIDTH` | `2304` | Image width |
| 27 | `IMAGE_HEIGHT` | `1296` | Image height |
| 28 | `IMAGE_QUALITY` | `100` | JPEG quality from 1 to 100 |
| 29 | `CP_ENVIRONMENT` | `staging` | `staging` or `production` |
| 30 | `CP_SUBMITTER_ID` | `nd` | Identifier assigned by Carbon Portal staff |
| 31 | `CP_STATION_URI` | `nd` | Canonical ICOS station URI |
| 32 | `CP_INSTRUMENT_URI` | `nd` | Canonical ICOS instrument URI |
| 33 | `ICOS_FILENAME_SUFFIX` | `nd` | Station-specific ICOS-approved suffix |
| 34 | `CAPTURE_MINUTE` | generated once | Stable offset within `INTERVAL_MIN` |

The complete commented template is
[`software/config/settings_example.txt`](../config/settings_example.txt).

## Capture Settings

The supported Camera Module 3 image-size pairs are:

| Width | Height | Sensor use |
| ---: | ---: | --- |
| 1536 | 864 | Central 3072 × 1728 area |
| 2304 | 1296 | Full 4608 × 2592 sensor area; project default |
| 4608 | 2592 | Full sensor resolution |

Width and height cannot be mixed between rows. JPEG quality accepts integers
from 1 through 100 and defaults to 100.

The acquisition window is evaluated in fixed station time as:

```text
START_HOUR <= current station hour < END_HOUR
```

## Persistent Acquisition Offset

The installer generates `CAPTURE_MINUTE` once and writes it to `settings.txt`.
For example, an interval of `30` and an offset of `13` request captures at
`:13` and `:43` of every hour. The value remains unchanged across reboots.

After explicitly changing `INTERVAL_MIN` or `CAPTURE_MINUTE`, apply the new
schedule with:

```bash
sudo /usr/local/lib/phenocam/bin/phenocam-configure-schedule.sh
```

The selected minute must be smaller than the interval.

## ICOS Identity

Keep `CP_ENVIRONMENT=staging` until end-to-end acceptance tests have succeeded.
Before upload can begin, replace the three `nd` values with values supplied or
confirmed by ICOS:

```text
CP_SUBMITTER_ID
CP_STATION_URI
CP_INSTRUMENT_URI
```

`CP_SUBMITTER_ID` is not the login email. The filename suffix controls only the
final component of:

```text
SITENAME_PHEN_YYYYMMDD_ICOS_FILENAME_SUFFIX.zip
```

The placeholder is `nd`, which disables submission without blocking capture.
Set the station-specific `Lxx_Fxx` value confirmed by ICOS. Current ICOS
examples follow this structure; the field remains configurable so a confirmed
future convention does not require changes to the packaging workflow.

## Staging Account

Edit the separate credentials file:

```bash
sudo nano /etc/phenocam/cp_credentials.txt
```

Its exact format is:

```text
account-email@example.org
account-password
```

The file must contain exactly these two non-empty lines. A final newline after
the password is optional.

The account belongs to this station installation. Credentials are read only at
upload time and are never copied into image metadata, command-line arguments or
logs.

## Activation Rules

The system continues capturing while ICOS configuration is incomplete.
Submission starts only when the following values are valid:

- `REMOTE_LAYOUT=icos`;
- `CP_ENVIRONMENT` is `staging` or `production`;
- `SITENAME` follows the ICOS station-code form;
- `CP_SUBMITTER_ID` is not `nd`;
- station and instrument URIs use their canonical ICOS forms;
- the filename suffix is valid;
- the credentials file contains both lines.

Missing identity retains source pairs. Missing credentials retains prepared
daily products in the outbox.

[Architecture](ARCHITECTURE.md) | [Operations](OPERATIONS.md) | [Project README](../../README.md)
