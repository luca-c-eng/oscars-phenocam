import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "detection_metadata.py"
SPEC = importlib.util.spec_from_file_location("detection_metadata", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


BASE = "[system]\nsitename=test\n"
VISION_FALSE = """[detection]
detected=false
software_name=phenocam-detection
software_version=0.2.3
model_id=yolo26n-phenocam
model_version=0.1.6
annotated_image=
privacy_image=
classes=
total_count=0
"""
VISION_TRUE = """[detection]
detected=true
software_name=phenocam-detection
software_version=0.2.3
model_id=yolo26n-phenocam
model_version=0.1.6
annotated_image=
privacy_image=image.jpg
classes=person,car
person_count=1
car_count=2
total_count=3
"""


class DetectionMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.meta = self.root / "image.meta"

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, text, mode=0o640):
        self.meta.write_text(text, encoding="utf-8", newline="")
        self.meta.chmod(mode)

    def state(self):
        text, _ = MODULE._read(self.meta)
        return MODULE._state(text)

    def assert_invalid(self, text):
        self.write(text)
        with self.assertRaises(MODULE.MetadataError):
            self.state()

    def test_pending_without_detection_section(self):
        self.write(BASE)
        self.assertEqual(self.state(), "pending")

    def test_mark_off_appends_only_integration_fields_atomically(self):
        self.write(BASE)
        before_inode = self.meta.stat().st_ino
        MODULE.mark_off(self.meta, "privacy")
        updated = self.meta.read_text(encoding="utf-8")
        self.assertEqual(self.state(), "off")
        self.assertIn(
            "[detection]\nfilter_enabled=off\nfilter_mode=privacy\n", updated
        )
        self.assertIn(BASE, updated)
        self.assertNotEqual(self.meta.stat().st_ino, before_inode)
        self.assertEqual(stat.S_IMODE(self.meta.stat().st_mode), 0o640)

    def test_mark_on_inserts_fields_before_valid_privacy_result(self):
        self.write(BASE + "\n" + VISION_TRUE)
        MODULE.mark_on(self.meta, "privacy")
        updated = self.meta.read_text(encoding="utf-8")
        self.assertEqual(self.state(), "ready")
        self.assertIn(
            "[detection]\nfilter_enabled=on\nfilter_mode=privacy\ndetected=true\n",
            updated,
        )

    def test_vendor_false_is_complete_metadata_inference(self):
        self.write(BASE + "\n" + VISION_FALSE)
        self.assertEqual(self.state(), "vision")
        MODULE.mark_on(self.meta, "metadata")
        self.assertEqual(self.state(), "ready")

    def test_annotated_mode_requires_annotated_image_name(self):
        annotated = VISION_TRUE.replace(
            "annotated_image=\nprivacy_image=image.jpg",
            "annotated_image=image.jpg\nprivacy_image=",
        )
        self.write(BASE + "\n" + annotated)
        MODULE.mark_on(self.meta, "annotated")
        self.assertEqual(self.state(), "ready")

    def test_crlf_is_retained_for_added_section(self):
        self.meta.write_bytes(BASE.replace("\n", "\r\n").encode())
        MODULE.mark_off(self.meta, "privacy")
        self.assertNotIn(b"\n", self.meta.read_bytes().replace(b"\r\n", b""))

    def test_wrong_vendor_identity_is_rejected(self):
        self.assert_invalid(BASE + "\n" + VISION_FALSE.replace("0.2.3", "0.2.2"))

    def test_multiple_detection_sections_are_rejected(self):
        self.assert_invalid(VISION_FALSE + "\n" + VISION_FALSE)

    def test_duplicate_field_is_rejected(self):
        invalid = VISION_FALSE.replace(
            "detected=false\n", "detected=false\ndetected=false\n"
        )
        self.assert_invalid(invalid)

    def test_symlink_is_rejected(self):
        target = self.root / "target.meta"
        target.write_text(BASE, encoding="utf-8")
        self.meta.symlink_to(target)
        with self.assertRaises(MODULE.MetadataError):
            MODULE._read(self.meta)

    def test_total_must_equal_class_count_sum(self):
        self.assert_invalid(VISION_TRUE.replace("total_count=3", "total_count=4"))

    def test_each_detected_class_requires_its_count(self):
        self.assert_invalid(VISION_TRUE.replace("car_count=2\n", ""))

    def test_false_result_rejects_class_count_fields(self):
        invalid = VISION_FALSE.replace("total_count=0", "person_count=1\ntotal_count=0")
        self.assert_invalid(invalid)

    def test_class_counts_must_be_positive(self):
        self.assert_invalid(VISION_TRUE.replace("person_count=1", "person_count=0"))

    def test_duplicate_classes_are_rejected(self):
        self.assert_invalid(VISION_TRUE.replace("classes=person,car", "classes=person,person"))

    def test_mark_on_rejects_output_for_wrong_mode(self):
        self.write(BASE + "\n" + VISION_TRUE)
        with self.assertRaises(MODULE.MetadataError):
            MODULE.mark_on(self.meta, "metadata")

    def test_delete_mode_rejects_detected_result(self):
        detected_without_outputs = VISION_TRUE.replace("privacy_image=image.jpg", "")
        self.write(BASE + "\n" + detected_without_outputs)
        with self.assertRaises(MODULE.MetadataError):
            MODULE.mark_on(self.meta, "delete")


if __name__ == "__main__":
    unittest.main()
