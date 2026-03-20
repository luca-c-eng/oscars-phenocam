#!/usr/bin/env bash
set -euo pipefail

# diag_camera.sh — lists cameras available to libcamera/rpicam.
# Run as root or as a user in the video group.

if command -v rpicam-hello >/dev/null 2>&1; then
  rpicam-hello --list-cameras
elif command -v libcamera-hello >/dev/null 2>&1; then
  libcamera-hello --list-cameras
else
  echo "Neither rpicam-hello nor libcamera-hello found."
  exit 1
fi
