# Documentazione specifica v1.5.0 per l'aggiunta della lettura temperatura della board
# Thermal and throttling monitoring

PhenoCam records Raspberry Pi runtime health information in every `.meta` file.

This feature is intended for Raspberry Pi Zero 2 W and Raspberry Pi 3B+, but it uses standard Raspberry Pi OS interfaces and should also work on other Raspberry Pi boards.

## Recorded metadata

Each `.meta` file contains a section named:

```text
[system_health]
```

Example:

```text
[system_health]
soc_temp_c=48.2
throttled_hex=0x0
arm_clock_mhz=1000
undervoltage_now=0
arm_freq_capped_now=0
throttled_now=0
soft_temp_limit_now=0
undervoltage_occurred=0
arm_freq_capped_occurred=0
throttled_occurred=0
soft_temp_limit_occurred=0
```

## Field meaning

| Field                      | Meaning                                               |
| -------------------------- | ----------------------------------------------------- |
| `soc_temp_c`               | Raspberry Pi SoC/core temperature in degrees Celsius  |
| `throttled_hex`            | Raw `vcgencmd get_throttled` bitmask                  |
| `arm_clock_mhz`            | Instantaneous ARM clock frequency in MHz              |
| `undervoltage_now`         | `1` if undervoltage is currently detected             |
| `arm_freq_capped_now`      | `1` if ARM frequency is currently capped              |
| `throttled_now`            | `1` if the system is currently throttled              |
| `soft_temp_limit_now`      | `1` if the soft temperature limit is currently active |
| `undervoltage_occurred`    | `1` if undervoltage occurred since boot               |
| `arm_freq_capped_occurred` | `1` if ARM frequency capping occurred since boot      |
| `throttled_occurred`       | `1` if throttling occurred since boot                 |
| `soft_temp_limit_occurred` | `1` if the soft temperature limit occurred since boot |

## Normal values

The ideal value is:

```text
throttled_hex=0x0
```

This means no current or historical undervoltage, throttling, frequency capping, or soft temperature limit flags since boot.

## Temperature interpretation

| SoC temperature | Interpretation                |
| --------------: | ----------------------------- |
|       `< 60 °C` | Normal                        |
|      `60–70 °C` | Warm but generally acceptable |
|      `70–80 °C` | Monitor                       |
|      `80–85 °C` | ARM throttling may occur      |
|      `>= 85 °C` | Higher throttling risk        |

For Raspberry Pi 3B+, the default soft temperature limit is 60 °C. When this limit is reached, the CPU clock may be reduced from 1.4 GHz to 1.2 GHz.

## Manual diagnostic command

Run:

```bash
sudo /usr/local/lib/phenocam/bin/diag_system_health.sh
```

Expected healthy output includes:

```text
soc_temp_c=...
throttled_hex=0x0
undervoltage_now=0
throttled_now=0
```

## Notes

These values do not represent ambient air temperature. They represent internal Raspberry Pi runtime health.

To measure true environmental temperature, add an external sensor such as DS18B20, BME280, SHT31, or similar.

