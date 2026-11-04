import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("metadata", Path(__file__).with_name("package-metadata.py"))
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class PackageMetadataTests(unittest.TestCase):
    def fixture(self, root, package="rtauargus.native"):
        (root / "DESCRIPTION").write_text(
            'Package: ' + package + '\nVersion: 1.3.7\nStagedInstall: no\n'
            'Authors@R: person("Original", "Author", role="aut")\n'
            'Description: Original first line.\n    Original second line.\n', encoding="utf-8")

    def lock(self, root):
        value = dict(repository="InseeFrLab/rtauargus", version="1.3.6", revision="a"*40,
                     description_sha256="b"*64)
        (root / "upstream.json").write_text(json.dumps(value), encoding="utf-8")
        return value

    def test_composite_preserves_original_authors_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.fixture(root)
            self.lock(root)
            self.assertEqual(metadata.update(root, "0.6.1"), "1.3.6-0.6.1")
            first = (root / "DESCRIPTION").read_text(encoding="utf-8")
            self.assertIn('person("Original", "Author", role="aut")', first)
            self.assertIn("Original first line.\n    Original second line.", first)
            self.assertNotIn("StagedInstall:", first)
            self.assertEqual(metadata.fields(first)["Config/tauargus/linkage"], "static")
            metadata.update(root, "0.6.1")
            self.assertEqual((root / "DESCRIPTION").read_text(encoding="utf-8"), first)

    def test_standalone_and_legacy_frontend_versions(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.fixture(root, "tauargusengine")
            self.assertEqual(metadata.update(root, "0.6.1"), "0.6.1")
            self.fixture(root)
            self.assertEqual(metadata.update(root, "0.6.1"), "1.3.7")

    def test_invalid_lock_or_native_version_leaves_description_unchanged(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.fixture(root)
            original = (root / "DESCRIPTION").read_bytes()
            for key in ("repository", "version", "revision", "description_sha256"):
                value = self.lock(root)
                value[key] = "invalid"
                (root / "upstream.json").write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaises(ValueError):
                    metadata.update(root, "0.6.1")
                self.assertEqual((root / "DESCRIPTION").read_bytes(), original)
            with self.assertRaises(ValueError):
                metadata.update(root, "0.6.1-rc1")


if __name__ == "__main__":
    unittest.main()
