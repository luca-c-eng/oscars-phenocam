# Testing

Run all commands in this document from the repository root.

## Requirements

- Python 3.13, as required by the target Raspberry Pi runtime.
- No third-party Python packages.
- No root privileges.

The tests use temporary files. They do not run ONNX inference, require the
Vision Edge model, or modify repository files.

## Detection Metadata

The detection metadata test suite covers
[`detection_metadata.py`](../scripts/detection_metadata.py).

Run:

```bash
python3 -m unittest -v software/tests/test_detection_metadata.py
```

The suite verifies:

- transitions between the `pending`, `vision`, `off`, and `ready` states;
- atomic writes and preservation of file permissions;
- LF and CRLF line endings;
- software and model identity fields;
- detection classes, per-class counts, and `total_count` consistency;
- output fields for `metadata`, `annotated`, `privacy`, and `delete` modes;
- rejection of duplicate fields, symbolic links, and inconsistent metadata.

A successful run exits with status `0` and ends with:

```text
Ran 17 tests in ...

OK
```

Any failed test produces a non-zero exit status.

---

[Back to the project README](../../README.md)
