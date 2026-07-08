# Clean installation — PhenoCam v1.4.0

This workflow is intended for a fresh Raspberry Pi OS Lite installation.

## 1. Install

Run as the normal sudo-enabled user, not as root:

```bash
curl -fsSL https://raw.githubusercontent.com/luca-c-eng/oscars-phenocam/dev/v1.4.0/software/install.sh | bash
```

The installer deploys the software, creates the `phenocam` system user, installs systemd units, prepares `/run/phenocam`, and leaves capture/upload timers disabled until configuration is complete.

## 2. Configure station settings

```bash
sudo nano /etc/phenocam/settings.txt
```

Minimum values to check:

```text
line 1   SITENAME
line 2   UTC_OFFSET
line 3   TZ_LABEL
line 4   START_HOUR
line 5   END_HOUR          end hour is exclusive
line 7   IFACE             wlan0 on Zero 2 W Wi-Fi, eth0 on Ethernet
line 8   SFTP_USER         only needed for SFTP
line 9   NET_MODE          wifi | ethernet | auto
line 14  REMOTE_LAYOUT     general | icos
line 21  BOARD             rpizero2w | rpi3b+ | unknown
line 22  CAMERA_MODEL      imx708 | imx708_noir
line 23  CAPTURE_TIMEOUT   30000 is validated
```

Example for RPi Zero 2 W on Wi-Fi:

```text
phenozero
+2
Europe/Rome
6
22
30
wlan0
phenocam
wifi
20
80
/media:/mnt
90
general
nd
nd
nd
nd
nd
nd
rpizero2w
imx708
30000
```

## 3. Configure upload

### FTP

```bash
sudo nano /etc/phenocam/ftp_credentials.txt
```

Format:

```text
FTP_HOST
FTP_PORT
FTP_REMOTE_BASE
FTP_USER
FTP_PASS
```

Example, if the provider exposes FTP on port 22:

```text
5.249.152.25
21
/phenocams/data
myuser
mypassword
```

### SFTP

SFTP is enabled only if `/etc/phenocam/server.txt` contains effective non-comment lines. Leave it empty or comment-only to disable SFTP.

## 4. Verify RAMDISK

```bash
df -h /run/phenocam
sudo ls -ld /run/phenocam /run/phenocam/queue /run/phenocam/staging
```

Expected owner:

```text
phenocam phenocam
```

## 5. Manual capture test

```bash
sudo rm -f /run/phenocam/capture.lock
sudo -u phenocam timeout --kill-after=10s 180s /usr/local/lib/phenocam/bin/phenocam-capture.sh
echo "RC=$?"
```

Expected:

```text
RC=0
/run/phenocam/queue/<site>_YYYY_MM_DD_HHMMSS.jpg
/run/phenocam/queue/<site>_YYYY_MM_DD_HHMMSS.meta
```

## 6. Manual upload test

```bash
sudo systemctl reset-failed phenocam-upload.service
sudo systemctl start phenocam-upload.service
sudo systemctl status phenocam-upload.service --no-pager -l
```

Expected:

```text
code=exited, status=0/SUCCESS
FTP uploaded and removed: <base> from /run/phenocam/queue
```

## 7. Enable production timers

```bash
sudo systemctl enable --now phenocam-capture.timer phenocam-upload.timer
systemctl list-timers 'phenocam-*' --all
```

## 8. Observe one automatic cycle

```bash
sudo tail -80 /var/log/phenocam/phenocam.log
sudo find /run/phenocam /var/lib/phenocam -type f \( -name '*.jpg' -o -name '*.meta' \) -ls 2>/dev/null
```

A file may remain in `/run/phenocam/queue` for a few minutes between capture and the next upload timer. This is normal.
