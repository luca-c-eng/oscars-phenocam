#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# net_check.sh — internet connectivity and network interface helpers.

# has_internet — returns 0 if a valid route to the internet exists.
# Uses 'ip route get' instead of ICMP ping (which may be blocked by firewalls).
has_internet() {
  ip route get 1.1.1.1 >/dev/null 2>&1
}

# resolve_iface — returns the network interface to use.
#
# Priority:
#   1. Explicit IFACE value, when IFACE is not "auto"
#   2. NET_MODE ethernet/wifi hint
#   3. Interface selected by the kernel default route
#   4. First non-loopback interface with a global IPv4 address
resolve_iface() {
  local requested="${IFACE:-auto}"
  local mode="${NET_MODE:-auto}"
  local route_iface=""

  # Explicit interface requested by configuration.
  if [[ -n "$requested" && "$requested" != "auto" ]]; then
    if ip link show "$requested" >/dev/null 2>&1; then
      echo "$requested"
      return 0
    fi
  fi

  case "$mode" in
    ethernet)
      ip -o -4 addr show scope global \
        | awk '$2 ~ /^(eth|en)/ {print $2; exit}'
      return 0
      ;;

    wifi)
      ip -o -4 addr show scope global \
        | awk '$2 ~ /^(wlan|wl)/ {print $2; exit}'
      return 0
      ;;

    auto|*)
      # Prefer the interface actually selected by the kernel for Internet traffic.
      route_iface="$(
        ip route get 1.1.1.1 2>/dev/null \
          | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
      )"

      if [[ -n "$route_iface" ]] &&
         ip -4 addr show "$route_iface" 2>/dev/null | grep -q 'inet '; then
        echo "$route_iface"
        return 0
      fi

      # Fallback when no Internet/default route is currently available.
      ip -o -4 addr show scope global \
        | awk '$2 != "lo" {print $2; exit}'
      ;;
  esac
}

# iface_ipv4 <interface> — returns the IPv4 address of the given interface.
iface_ipv4() {
  local iface="$1"
  ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true
}
