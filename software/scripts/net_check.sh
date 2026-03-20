#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# net_check.sh — internet connectivity and network interface helpers.

# has_internet — returns 0 if a valid route to the internet exists.
# Uses 'ip route get' instead of ICMP ping (which may be blocked by firewalls).
has_internet() {
  ip route get 1.1.1.1 >/dev/null 2>&1
}

# resolve_iface — returns the network interface to use, based on settings.
# Priority: explicit IFACE setting → NET_MODE hint → auto-detect.
resolve_iface() {
  local i

  if [[ -n "${IFACE:-}" ]]; then
    ip link show "$IFACE" >/dev/null 2>&1 && { echo "$IFACE"; return 0; }
  fi

  case "${NET_MODE:-auto}" in
    ethernet)
      for i in eth0 en*; do
        ip link show "$i" >/dev/null 2>&1 && { echo "$i"; return 0; }
      done
      ;;
    wifi)
      for i in wlan0 wl*; do
        ip link show "$i" >/dev/null 2>&1 && { echo "$i"; return 0; }
      done
      ;;
    auto|*)
      ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | while read -r i; do
        ip -4 addr show "$i" | grep -q 'inet ' && { echo "$i"; return 0; }
      done
      ;;
  esac

  echo ""
}

# iface_ipv4 <interface> — returns the IPv4 address of the given interface.
iface_ipv4() {
  local iface="$1"
  ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true
}
