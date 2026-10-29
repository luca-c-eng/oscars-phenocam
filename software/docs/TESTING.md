# Testing

Run these commands from the repository root. The automated suites use
temporary files and local HTTP services; they do not contact ICOS, require root
privileges or execute ONNX inference.

## Core Test Suite

```bash
bash software/tests/test_capture_config.sh
bash software/tests/test_vision_config.sh
python3 -m unittest -v software/tests/test_detection_metadata.py
bash software/tests/test_detection_manager.sh
bash software/tests/test_icos_config.sh
bash software/tests/test_schedule_manager.sh
bash software/tests/test_queue_manager.sh
bash software/tests/test_icos_manager.sh
python3 -m unittest -v software/tests/test_icos_client.py
bash software/tests/test_system_integration.sh
```

The ICOS-specific suites verify:

- staging/production selection and rejection of invalid values;
- filename-suffix and persistent-minute validation;
- 30- and 15-minute systemd schedules;
- verified JPEG/META queue publication, collision protection and temporary-file cleanup;
- daily pair discovery and root-level, JPEG-only uncompressed ZIP creation;
- full station-day UTC acquisition interval generation;
- SHA-256 JSON metadata generation;
- CPauth cookie acquisition;
- authenticated metadata POST and chunked archive PUT;
- rejection of successful logins without a `cpauthToken`;
- retry of the data PUT without repeating a completed metadata POST;
- distinct retryable and blocked error classes;
- local receipt creation and verified source cleanup;
- ICOS runtime completeness, safe base timers and service timeout contracts.

## Static Checks

```bash
python3 -m py_compile \
  software/scripts/icos_client.py \
  software/scripts/detection_metadata.py

bash -n install.sh software/bin/*.sh software/scripts/*.sh software/tests/*.sh
git diff --check
```

## Real Staging Acceptance Test

Automated tests cannot replace one authenticated staging submission. The final
acceptance test requires:

- an authorized staging account;
- the assigned `submitterId`;
- the canonical station URI;
- the canonical instrument URI;
- a confirmed filename suffix.

Run the installed upload service after configuring these values. A successful
test must create a receipt in `/var/lib/phenocam/icos-receipts` and the object
must be confirmed in the Carbon Portal staging environment.

[Architecture](ARCHITECTURE.md) | [Configuration](CONFIGURATION.md) | [Project README](../../README.md)
