# System Health and Thermal Monitoring

OSCARS-PHENOCAM collects Raspberry Pi health values during metadata generation and provides a diagnostic command for manual inspection.

Monitoring is passive. The software records and displays the values but does not:

* stop image acquisition;
* change the capture schedule;
* restart services;
* generate alerts;
* modify throttling or power-management settings.

---

## Manual Health Check

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

The command calls the same functions used during metadata generation and displays:

* SoC temperature;
* raw throttling value;
* ARM clock frequency;
* decoded current flags;
* decoded historical flag bits.

---

## Temperature

The software first attempts to read:

```text
/sys/class/thermal/thermal_zone0/temp
```

The integer value is divided by `1000` and formatted with one decimal place:

```text
soc_temp_c=<value>
```

If the sysfs file is unavailable, the software attempts:

```bash
vcgencmd measure_temp
```

If neither source is available:

```text
soc_temp_c=nd
```

Health values are collected after JPEG acquisition, while the metadata sidecar is being generated.

---

## Diagnostic Temperature Guide

`diag_system_health.sh` prints this informational guide:

| Temperature     | Diagnostic text            |
| --------------- | -------------------------- |
| Below 60 °C     | Normal                     |
| 60–70 °C        | Warm, generally acceptable |
| 70–80 °C        | Monitor                    |
| 80–85 °C        | ARM throttling may occur   |
| 85 °C or higher | Stronger throttling risk   |

These ranges are printed for interpretation only. No conditional action in the software uses them.

---

## Throttling Value

The raw value is requested with:

```bash
vcgencmd get_throttled
```

The `throttled=` prefix is removed and the result is recorded as:

```text
throttled_hex=<value>
```

If `vcgencmd` is unavailable:

```text
throttled_hex=nd
```

A value of:

```text
throttled_hex=0x0
```

causes all decoded flag fields implemented by the software to contain `0`.

The software reads and decodes this value. It does not modify or clear it.

---

## Current Flag Bits

| Metadata field        | Bit decoded by the software | Diagnostic meaning                             |
| --------------------- | --------------------------: | ---------------------------------------------- |
| `undervoltage_now`    |                           0 | Supply voltage is currently too low            |
| `arm_freq_capped_now` |                           1 | ARM frequency is currently capped              |
| `throttled_now`       |                           2 | The system is currently throttled              |
| `soft_temp_limit_now` |                           3 | The soft temperature limit is currently active |

---

## Historical Flag Bits

| Metadata field             | Bit decoded by the software | Diagnostic meaning                                 |
| -------------------------- | --------------------------: | -------------------------------------------------- |
| `undervoltage_occurred`    |                          16 | Undervoltage has occurred since boot               |
| `arm_freq_capped_occurred` |                          17 | ARM-frequency capping has occurred since boot      |
| `throttled_occurred`       |                          18 | Throttling has occurred since boot                 |
| `soft_temp_limit_occurred` |                          19 | The soft temperature limit has occurred since boot |

These descriptions reproduce the interpretation printed by `diag_system_health.sh`.

The project code does not control the lifecycle of the underlying Raspberry Pi flags. It only reads and decodes the value returned by `vcgencmd`.

---

## Decoded Values

Each decoded flag field contains:

```text
0
1
nd
```

where:

* `0` means the selected bit is not set;
* `1` means the selected bit is set;
* `nd` means the raw hexadecimal value could not be decoded.

The conversion accepts values matching:

```text
0x<hexadecimal digits>
```

---

## ARM Clock

The ARM clock is requested with:

```bash
vcgencmd measure_clock arm
```

The numeric result is converted from hertz to megahertz and formatted without decimal places:

```text
arm_clock_mhz=<value>
```

If `vcgencmd` is unavailable or its returned value is not numeric:

```text
arm_clock_mhz=nd
```

---

## Metadata Integration

Each successfully generated sidecar contains:

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

The values are collected separately for every generated metadata file.

For the complete sidecar format, see [Metadata](METADATA.md).

---

[Operations](OPERATIONS.md) · [Back to the project README](../../README.md)

