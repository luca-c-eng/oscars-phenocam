software/
├── bin/        # executable entrypoints (called by systemd or manually)
│   ├── phenocam-capture.sh   → called by phenocam-capture.service (capture timer)
│   │                           runs one acquisition cycle (capture + meta + enqueue)
│   ├── phenocam-upload.sh    → called by phenocam-upload.service (upload timer)
│   │                           drains all queues (RAM → USB → SD) to the server
│   ├── phenocam-run.sh       → manual entrypoint: runs capture then upload
│   │                           also used by phenocam-init.service at boot
│   ├── phenocam-usb-attach.sh → called by udev on USB plug-in
│   │                            waits for automount, creates queue dir, logs event
│   ├── phenocam-usb-detach.sh → called by udev on USB removal
│   │                            performs lazy unmount, cleans orphan .tmp files
│   └── diag_*.sh             → diagnostic tools (camera, network, RAMDISK, upload)

├── scripts/    # reusable logic modules (sourced by bin/ scripts)
│   ├── common.sh          → logging (info/warn/err/die), with_lock
│   ├── config_read.sh     → reads settings.txt (positional), exports variables:
│   │                        SITENAME, START_HOUR, END_HOUR, INTERVAL_MIN,
│   │                        NET_MODE, RAM_MIN_FREE_MB, SD_MAX_USED_PCT,
│   │                        USB_MOUNT_BASES, USB_MAX_USED_PCT, ...
│   ├── capture_vis.sh     → VIS image capture wrapper (rpicam-still / libcamera-still)
│   ├── meta_build.sh      → builds .meta file with EXIF (exiftool) + network info
│   ├── net_check.sh       → internet connectivity check (ip route, no ICMP)
│   ├── storage_manager.sh → queue directory paths + disk space helpers
│   ├── queue_manager.sh   → decides where to enqueue (RAMDISK → USB → SD)
│   ├── uploader_daemon.sh → drains queues, selects upload method (SFTP/FTP)
│   ├── upload_sftp.sh     → upload_pair_sftp(): sends jpg+meta via SFTP + SSH key
│   └── upload_ftp.sh      → upload_pair_ftp(): sends jpg+meta via FTP + curl

├── config/     # configuration file examples
│   ├── settings_example.txt       → example settings.txt (20 positional fields)
│   ├── server_example.txt         → example server.txt for SFTP
│   ├── ftp_credentials.txt        → placeholder (replace with real values on RPi)
│   └── ftp_credentials_example.txt → annotated FTP credentials example

└── systemd/    # systemd unit files and udev rules
    ├── phenocam-capture.service   → capture service (oneshot, user=phenocam)
    ├── phenocam-capture.timer     → capture timer (OnCalendar=*:0,30)
    ├── phenocam-upload.service    → upload service (oneshot, user=phenocam)
    ├── phenocam-upload.timer      → upload timer (every 9 minutes)
    ├── phenocam-init.service      → boot init: mkdir, chown RAMDISK, first cycle
    ├── run-phenocam.mount         → RAMDISK tmpfs 200MB at /run/phenocam
    └── 99-phenocam-usb.rules      → udev rule for USB hot-plug (FAT32 required)
