#!/usr/bin/env bash
set -euo pipefail

# diag_net.sh — shows network interfaces, IPv4 addresses and routing table.

echo "=== ip link ==="
ip link

echo "=== ip -4 addr ==="
ip -4 addr

echo "=== routing table ==="
ip route
