# System Health and Thermal Monitoring

OSCARS-PHENOCAM records Raspberry Pi health information during metadata generation and provides a command for manual inspection.

The monitoring is passive: the current software does not stop captures, change their frequency, restart services, or generate alerts in response to temperature or throttling conditions.

---

## Manual Health Check

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

The command displays:

* SoC temperature;
* raw throttling status;
* ARM clock frequency;
* current power and throttling flags;
* conditions recorded since boot.

---

## Temperature

The software reads the SoC temperature from:

```text
/sys/class/thermal/thermal_zone0/temp
```

If this source is unavailable, it attempts:

```bash
vcgencmd measure_temp
```

The value is reported in degrees Celsius with one decimal place:

```text
soc_temp_c=<value>
```

If no temperature source is available, the value is:

```text
soc_temp_c=nd
```

### Diagnostic Temperature Guide

The diagnostic script reports the following interpretation:

| Temperature       | Interpretation             |
| ----------------- | -------------------------- |
| Below `60 °C`     | Normal                     |
| `60–70 °C`        | Warm, generally acceptable |
| `70–80 °C`        | Monitor                    |
| `80–85 °C`        | ARM throttling may occur   |
| `85 °C` or higher | Stronger throttling risk   |

These ranges are informational only and do not trigger automatic actions.

---

## Throttling Status

The raw Raspberry Pi status is read with:

```bash
vcgencmd get_throttled
```

It is recorded as:

```text
throttled_hex=<hexadecimal value>
```

A value of:

```text
throttled_hex=0x0
```

means that none of the current or historical flags decoded by the software are set.

---

## Current Flags

| Field                 | Bit | Meaning when equal to `1`                      |
| --------------------- | --: | ---------------------------------------------- |
| `undervoltage_now`    |   0 | Supply voltage is currently too low            |
| `arm_freq_capped_now` |   1 | ARM frequency is currently capped              |
| `throttled_now`       |   2 | The system is currently throttled              |
| `soft_temp_limit_now` |   3 | The soft temperature limit is currently active |

---

## Historical Flags

| Field                      | Bit | Meaning when equal to `1`                          |
| -------------------------- | --: | -------------------------------------------------- |
| `undervoltage_occurred`    |  16 | Undervoltage has occurred since boot               |
| `arm_freq_capped_occurred` |  17 | ARM-frequency capping has occurred since boot      |
| `throttled_occurred`       |  18 | Throttling has occurred since boot                 |
| `soft_temp_limit_occurred` |  19 | The soft temperature limit has occurred since boot |

Historical flags remain set until the Raspberry Pi is rebooted.

Decoded flag values are:

```text
0  flag not set
1  flag set
nd value unavailable
```

---

## ARM Clock

The ARM clock is read with:

```bash
vcgencmd measure_clock arm
```

The result is converted from hertz to megahertz and recorded as:

```text
arm_clock_mhz=<value>
```

If the returned value is unavailable or non-numeric:

```text
arm_clock_mhz=nd
```

---

## Metadata Integration

Each captured image receives the same health information in the `[system_health]` section of its `.meta` sidecar:

```text
[system_health]
soc_temp_c=<value>
throttled_hex=<value>
arm_clock_mhz=<value>
undervoltage_now=<0|1|nd>
arm_freq_capped_now=<0|1|nd>
throttled_now=<0|1|nd>
soft_temp_limit_now=<0|1|nd>
undervoltage_occurred=<0|1|nd>
arm_freq_capped_occurred=<0|1|nd>
throttled_occurred=<0|1|nd>
soft_temp_limit_occurred=<0|1|nd>
```

Health values are collected after image acquisition, while the metadata sidecar is being generated.

For the complete sidecar structure, see [Metadata](METADATA.md).

---

[Operations](OPERATIONS.md) · [Back to the project README](../../README.md)
