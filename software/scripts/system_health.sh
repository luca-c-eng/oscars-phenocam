#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# system_health.sh — Raspberry Pi runtime health helpers.
#
# Provides:
#   - SoC/core temperature in Celsius
#   - vcgencmd throttling/undervoltage state
#   - optional ARM clock frequency
#
# Works on Raspberry Pi Zero 2 W and Raspberry Pi 3B+.

read_soc_temp_c() {
  if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
    awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp
    return 0
  fi

  if command -v vcgencmd >/dev/null 2>&1; then
    vcgencmd measure_temp 2>/dev/null | sed -E "s/^temp=([0-9.]+).*/\1/" || true
    return 0
  fi

  echo "nd"
}

read_throttled_hex() {
  if command -v vcgencmd >/dev/null 2>&1; then
    vcgencmd get_throttled 2>/dev/null | sed -E 's/^throttled=//' || true
  else
    echo "nd"
  fi
}

read_arm_clock_mhz() {
  if command -v vcgencmd >/dev/null 2>&1; then
    local hz
    hz="$(vcgencmd measure_clock arm 2>/dev/null | sed -E 's/^frequency\([0-9]+\)=//' || true)"
    if [[ "$hz" =~ ^[0-9]+$ ]]; then
      awk -v hz="$hz" 'BEGIN { printf "%.0f", hz/1000000 }'
    else
      echo "nd"
    fi
  else
    echo "nd"
  fi
}

hex_to_dec() {
  local h="$1"
  if [[ "$h" =~ ^0x[0-9a-fA-F]+$ ]]; then
    printf "%d" "$h"
  else
    echo ""
  fi
}

throttled_bit_is_set() {
  local hex="$1"
  local bit="$2"
  local dec

  dec="$(hex_to_dec "$hex")"
  if [[ -z "$dec" ]]; then
    echo "nd"
    return 0
  fi

  if (( dec & (1 << bit) )); then
    echo "1"
  else
    echo "0"
  fi
}

print_system_health_kv() {
  local t h

  t="$(read_soc_temp_c)"
  h="$(read_throttled_hex)"

  echo "soc_temp_c=${t}"
  echo "throttled_hex=${h}"
  echo "arm_clock_mhz=$(read_arm_clock_mhz)"

  echo "undervoltage_now=$(throttled_bit_is_set "$h" 0)"
  echo "arm_freq_capped_now=$(throttled_bit_is_set "$h" 1)"
  echo "throttled_now=$(throttled_bit_is_set "$h" 2)"
  echo "soft_temp_limit_now=$(throttled_bit_is_set "$h" 3)"

  echo "undervoltage_occurred=$(throttled_bit_is_set "$h" 16)"
  echo "arm_freq_capped_occurred=$(throttled_bit_is_set "$h" 17)"
  echo "throttled_occurred=$(throttled_bit_is_set "$h" 18)"
  echo "soft_temp_limit_occurred=$(throttled_bit_is_set "$h" 19)"
}
