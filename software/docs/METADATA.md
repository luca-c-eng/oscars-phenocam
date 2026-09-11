# Metadata

OSCARS-PHENOCAM creates one plain-text `.meta` sidecar for every captured JPEG image.

The image and metadata files share the same base name:

```text
SITENAME_YYYY_MM_DD_HHMMSS.jpg
SITENAME_YYYY_MM_DD_HHMMSS.meta
```

The filename timestamp is generated immediately before image capture, using the configured fixed station time.

---

## File Structure

Each `.meta` file contains five sections:

```text
[system]
[phenocam]
[system_health]
[capture_params_fixed]
[exif]
```

The first four sections use `key=value` records. The `[exif]` section contains the grouped text output produced by `exiftool`.

---

## `[system]`

| Field               | Content                                                |
| ------------------- | ------------------------------------------------------ |
| `sitename`          | Station identifier from `SITENAME`                     |
| `hostname`          | Fully qualified hostname, with local hostname fallback |
| `timestamp`         | Sidecar-generation time in ISO 8601 format             |
| `datetime_original` | Quoted copy of `timestamp`                             |
| `tz`                | Fixed timezone label generated from `UTC_OFFSET`       |
| `utc_offset`        | Configured station UTC offset                          |
| `network`           | Selected remote layout: `general` or `icos`            |
| `lat`               | Configured site latitude                               |
| `lon`               | Configured site longitude                              |
| `elev`              | Configured site elevation                              |
| `start_date`        | Configured site start date                             |
| `end_date`          | Configured site end date                               |
| `nimage`            | Configured site image value                            |
| `iface`             | Selected network interface                             |
| `ip`                | IPv4 address of the selected interface                 |
| `mac`               | MAC address of the selected interface                  |
| `image_file`        | JPEG filename without its local path                   |

`timestamp` and `datetime_original` are created after image acquisition, when metadata generation begins. They may therefore differ slightly from the timestamp contained in the filename.

The `network` field records `REMOTE_LAYOUT`. It does not identify the active interface or whether FTP or SFTP is being used.

If no network interface is resolved, `iface`, `ip`, and `mac` may be empty.

---

## `[phenocam]`

| Field              | Content                                    |
| ------------------ | ------------------------------------------ |
| `software_name`    | Installed software name                    |
| `software_version` | Value installed from `software/VERSION`    |
| `software_branch`  | Repository branch used during installation |
| `software_commit`  | Short Git commit identifier                |
| `installed_at`     | Installation timestamp in ISO 8601 format  |

These values are normally read from:

```text
/usr/local/lib/phenocam/BUILD_INFO
```

If `BUILD_INFO` is unavailable, the software uses `/usr/local/lib/phenocam/VERSION` when possible and writes `nd` for unavailable build information.

---

## `[system_health]`

| Field                      | Content                                         |
| -------------------------- | ----------------------------------------------- |
| `soc_temp_c`               | Raspberry Pi SoC temperature in degrees Celsius |
| `throttled_hex`            | Raw `vcgencmd get_throttled` value              |
| `arm_clock_mhz`            | Current ARM clock frequency in MHz              |
| `undervoltage_now`         | Current undervoltage flag                       |
| `arm_freq_capped_now`      | Current ARM-frequency limitation flag           |
| `throttled_now`            | Current throttling flag                         |
| `soft_temp_limit_now`      | Current soft-temperature-limit flag             |
| `undervoltage_occurred`    | Undervoltage detected since boot                |
| `arm_freq_capped_occurred` | ARM-frequency limitation detected since boot    |
| `throttled_occurred`       | Throttling detected since boot                  |
| `soft_temp_limit_occurred` | Soft temperature limit detected since boot      |

Boolean health fields contain:

```text
0
1
nd
```

Where:

* `0` means the flag is not set;
* `1` means the flag is set;
* `nd` means the value could not be determined.

Temperature is read from `/sys/class/thermal/thermal_zone0/temp` when available, otherwise through `vcgencmd`.

For health interpretation, see [System Health and Thermal Monitoring](THERMAL_MONITORING.md).

---

## `[capture_params_fixed]`

| Field           | Default value |
| --------------- | ------------: |
| `width`         |        `4608` |
| `height`        |        `2592` |
| `awb`           |    `daylight` |
| `gain`          |         `1.0` |
| `sharpness`     |         `1.0` |
| `contrast`      |         `1.0` |
| `brightness`    |           `0` |
| `saturation`    |         `1.0` |
| `denoise`       |         `off` |
| `ev`            |           `0` |
| `lens_position` |         `0.0` |
| `quality`       |         `100` |

These values correspond to the parameters passed to `rpicam-still` or `libcamera-still`.

The capture warm-up value `CAPTURE_TIMEOUT` and the operating-system timeout guard are not written to this section.

---

## `[exif]`

The `[exif]` section is generated with:

```bash
exiftool -a -u -g1 <image.jpg>
```

It contains grouped EXIF information extracted from the JPEG, including duplicate and unknown tags reported by `exiftool`.

Unlike the previous sections, this content is not normalized into `key=value` records.

Metadata generation fails when `exiftool` is unavailable.

---

## Configuration Values Not Recorded

The following values are read from `settings.txt` but are not written to the `.meta` file in v1.7.0:

* `INTERVAL_MIN`
* `BOARD`
* `CAMERA_MODEL`
* `CAPTURE_TIMEOUT`

`BOARD` and `CAMERA_MODEL` also have no runtime effect after being loaded by the current software.

---

## Pair Lifecycle

The `.jpg` and `.meta` files are moved into the selected queue as one logical pair.

The uploader processes only complete pairs. When an enabled upload target fails, both local files remain queued for a later attempt.

---

[Configuration](CONFIGURATION.md) · [Operations](OPERATIONS.md) · [Back to the project README](../../README.md)
