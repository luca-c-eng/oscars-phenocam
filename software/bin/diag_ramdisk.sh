#!/usr/bin/env bash
set -euo pipefail

# diag_ramdisk.sh — shows RAMDISK mount status and usage.

echo "=== tmpfs mounts ==="
mount | grep tmpfs || true

echo "=== /run usage ==="
df -h /run || true

echo "=== /run/phenocam contents ==="
ls -lah /run/phenocam 2>/dev/null || true
