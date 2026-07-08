# Development notes — v1.4.0 Zero 2 W validation

Validated operational findings transferred into dev/v1.4.0:

1. `CAPTURE_TIMEOUT=30000` is normal and required on Zero 2 W. It is camera warm-up time, not a maximum runtime.
2. `rpicam-still` may take more than 30 seconds end-to-end. The service timeout must be wider; `TimeoutStartSec=300` is used.
3. Inline Bash inside `phenocam-init.service` can be fragile. RAMDISK sizing and ownership are moved to `bin/phenocam-init-ramdisk.sh`.
4. `/run/phenocam` must be writable by user `phenocam`, not only its subdirectories, because locks are created directly under `/run/phenocam`.
5. The RAMDISK mount should include uid/gid-aware options after the `phenocam` user exists.
6. FTP port is configuration. FTP on port 22 remains FTP and must use `ftp://`, not SFTP.
7. SFTP must not be attempted if `server.txt` is empty or contains only comments/blank lines.
8. If both SFTP and FTP are configured, local deletion is safe only after every configured target succeeds.
9. Direct upload works, but atomic remote upload/rename remains a future improvement if the FTP server supports reliable RNFR/RNTO semantics.

Validated production indicators:

```text
Capture VIS -> staging/<base>.jpg
Build meta -> staging/<base>.meta
Enqueued -> /run/phenocam/queue
FTP uploaded and removed -> queue
```
