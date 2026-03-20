#!/usr/bin/env bash
set -euo pipefail

# diag_upload.sh — checks upload prerequisites without attempting any transfer.

CONFIG="/etc/phenocam"
KEY="${CONFIG}/keys/phenocam_key"

echo "=== SFTP prerequisites ==="
echo -n "server.txt:    "; [[ -s "${CONFIG}/server.txt" ]] && echo "OK (not empty)" || echo "EMPTY or missing (SFTP disabled)"
echo -n "phenocam_key:  "; [[ -f "$KEY" ]] && echo "OK" || echo "MISSING"
echo -n "known_hosts:   "; [[ -f "${CONFIG}/known_hosts" ]] && echo "OK" || echo "MISSING"

echo ""
echo "=== FTP prerequisites ==="
echo -n "ftp_credentials.txt: "
[[ -s "${CONFIG}/ftp_credentials.txt" ]] && echo "OK (not empty)" || echo "EMPTY or missing (FTP disabled)"

echo ""
echo "=== SSH public key (send to SFTP server administrator) ==="
if [[ -f "${CONFIG}/keys/phenocam_key.pub" ]]; then
  cat "${CONFIG}/keys/phenocam_key.pub"
else
  echo "Key not generated yet. Run: sudo ssh-keygen -t ed25519 -f ${KEY} -N \"\""
fi
