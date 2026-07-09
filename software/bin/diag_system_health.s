# Diagnostica manuale per RPi Zero 2 W e RPi 3B+
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE="/usr/local/lib/phenocam"
source "${BASE}/scripts/system_health.sh"

echo "PhenoCam system health"
echo "======================"
echo ""

print_system_health_kv

echo ""
echo "Interpretation"
echo "--------------"
echo "throttled_hex=0x0 means no current or historical undervoltage/throttling flags."
echo ""
echo "Current flags:"
echo "  undervoltage_now=1       -> power supply voltage is currently too low"
echo "  arm_freq_capped_now=1    -> ARM frequency is currently capped"
echo "  throttled_now=1          -> system is currently throttled"
echo "  soft_temp_limit_now=1    -> soft temperature limit is currently active"
echo ""
echo "Historical flags:"
echo "  *_occurred=1 means the condition happened since boot."
echo ""
echo "Temperature guide:"
echo "  <60 C    normal"
echo "  60-70 C  warm, generally acceptable"
echo "  70-80 C  monitor"
echo "  80-85 C  ARM throttling may occur"
echo "  >=85 C   stronger throttling risk"
