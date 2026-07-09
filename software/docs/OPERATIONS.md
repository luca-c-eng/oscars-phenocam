# Operations

## Service and timer status

```bash
systemctl status phenocam-init.service phenocam-capture.timer phenocam-upload.timer --no-pager -l
systemctl list-timers 'phenocam-*' --all
```

`Type=oneshot` services normally end as `inactive (dead)` after success. The important status is `code=exited, status=0/SUCCESS`.

## Start/stop production

```bash
sudo systemctl enable --now phenocam-capture.timer phenocam-upload.timer
sudo systemctl stop phenocam-capture.timer phenocam-upload.timer
```

## Manual capture

```bash
sudo rm -f /run/phenocam/capture.lock
sudo -u phenocam timeout --kill-after=10s 180s /usr/local/lib/phenocam/bin/phenocam-capture.sh
echo "RC=$?"
```

## Manual upload

```bash
sudo systemctl reset-failed phenocam-upload.service
sudo systemctl start phenocam-upload.service
sudo systemctl status phenocam-upload.service --no-pager -l
```

## Check queue

```bash
sudo find /run/phenocam /var/lib/phenocam -type f \( -name '*.jpg' -o -name '*.meta' \) -ls 2>/dev/null
```

## Check JPEG completeness without xxd

```bash
file="/path/to/image.jpg"
tail -c 2 "$file" | od -An -tx1
```

Expected JPEG end marker:

```text
ff d9
```

## RAMDISK caution

Do not restart or remount `run-phenocam.mount` while files are waiting in `/run/phenocam/queue`, unless losing those volatile files is acceptable.

## System health diagnostic

To check Raspberry Pi temperature and throttling state:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh

Healthy output should normally show:

```text
throttled_hex=0x0
undervoltage_now=0
throttled_now=0
```
Every .meta file also contains a [system_health] section with SoC temperature and throttling flags.
