--- Diagnostic and entrypoint scripts ---

bin/diag_camera.sh   → lists available cameras via rpicam-hello --list-cameras
bin/diag_net.sh      → shows network interfaces, IPv4 addresses, routing table
bin/diag_ramdisk.sh  → shows tmpfs mounts and /run/phenocam usage
bin/diag_upload.sh   → checks upload prerequisites (server.txt, key, known_hosts)
bin/phenocam-run.sh  → manual entrypoint: capture + upload in sequence
                       also called by phenocam-init.service at every boot
