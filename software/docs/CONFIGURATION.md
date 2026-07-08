# Configuration reference

## settings.txt fields

`/etc/phenocam/settings.txt` is positional. Comments and blank lines are ignored, so keep every real field as a non-empty line.

| Line | Name | Example | Notes |
|---:|---|---|---|
| 1 | SITENAME | phenozero | Used in filenames and remote path |
| 2 | UTC_OFFSET | +2 | Summer Rome is +2, winter is +1 |
| 3 | TZ_LABEL | Europe/Rome | Metadata label |
| 4 | START_HOUR | 6 | Capture window start |
| 5 | END_HOUR | 22 | End is exclusive |
| 6 | INTERVAL_MIN | 30 | Timer currently fires at :00 and :30 |
| 7 | IFACE | wlan0 | Use wlan0 for Zero 2 W Wi-Fi |
| 8 | SFTP_USER | phenocam | Used only by SFTP |
| 9 | NET_MODE | wifi | auto, ethernet, wifi |
| 10 | RAM_MIN_FREE_MB | 20 | Spillover threshold |
| 11 | SD_MAX_USED_PCT | 80 | SD protection threshold |
| 12 | USB_MOUNT_BASES | /media:/mnt | USB scan roots |
| 13 | USB_MAX_USED_PCT | 90 | USB spillover threshold |
| 14 | REMOTE_LAYOUT | general | general or icos |
| 15 | SITE_LAT | nd | Decimal degrees or nd |
| 16 | SITE_LON | nd | Decimal degrees or nd |
| 17 | SITE_ELEV_M | nd | Metres or nd |
| 18 | SITE_START_DATE | nd | YYYY-MM-DD or nd |
| 19 | SITE_END_DATE | nd | YYYY-MM-DD or nd |
| 20 | SITE_NIMAGE | nd | Count or nd |
| 21 | BOARD | rpizero2w | rpi3b+, rpizero2w, unknown |
| 22 | CAMERA_MODEL | imx708 | imx708, imx708_noir |
| 23 | CAPTURE_TIMEOUT | 30000 | rpicam warm-up time in ms |

## Capture timeout

`CAPTURE_TIMEOUT=30000` means the camera command waits about 30 seconds before taking the still image. This is expected and validated on Zero 2 W. It is not the same as a maximum process runtime.

The service-level timeout is wider:

```ini
TimeoutStartSec=300
```

The capture wrapper also uses an OS-level guard to prevent rare indefinite hangs.

## FTP

`/etc/phenocam/ftp_credentials.txt` requires 5 non-comment lines:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

FTP can use a provider-defined port. Port `22` is accepted if the protocol is FTP.

## SFTP

SFTP is enabled only when `/etc/phenocam/server.txt` contains at least one non-comment, non-empty line. An empty or comment-only file disables SFTP.

If both FTP and SFTP are configured, the uploader attempts both targets and deletes the local file pair only after all configured targets succeed.
