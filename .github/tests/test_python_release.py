"""The two Python distributions form one versioned release."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "python_release", Path(__file__).parents[1] / "scripts/python_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class PythonReleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for directory, name in [("python", "pytauargus"), ("tui", "pytauargus-tui")]:
            path = self.root / "bindings" / directory
            path.mkdir(parents=True)
            deps = '["pytauargus==0.3.0", "textual>=0.50"]' if directory == "tui" else "[]"
            (path / "pyproject.toml").write_text(
                f'[project]\nname = "{name}"\nversion = "0.3.0"\ndependencies = {deps}\n')
            packages = '[[package]]\nname = "pytauargus"\nversion = "0.3.0"\n'
            if directory == "tui":
                packages += '[[package]]\nname = "pytauargus-tui"\nversion = "0.3.0"\n'
            (path / "uv.lock").write_text(packages)

    def change(self, filename, before, after):
        path = self.root / filename
        path.write_text(path.read_text().replace(before, after))

    def test_one_tag_releases_matching_packages(self):
        self.assertEqual(release.check_release(self.root, "py-v0.3.0"), "0.3.0")

    def test_tui_cannot_drift_from_engine_version(self):
        self.change("bindings/tui/pyproject.toml", 'version = "0.3.0"', 'version = "0.1.0"')
        with self.assertRaisesRegex(ValueError, "versions"):
            release.check_release(self.root)

    def test_tui_requires_the_matching_engine(self):
        self.change("bindings/tui/pyproject.toml", "pytauargus==0.3.0", "pytauargus>=0.3.0")
        with self.assertRaisesRegex(ValueError, "dependency"):
            release.check_release(self.root)

    def test_separate_tui_tag_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "tag"):
            release.check_release(self.root, "tui-v0.3.0")

    def test_unrelated_release_tag_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "tag"):
            release.check_release(self.root, "py-v0.4.0")

    def test_stale_lock_version_is_rejected(self):
        self.change("bindings/tui/uv.lock", 'version = "0.3.0"', 'version = "0.2.0"')
        with self.assertRaisesRegex(ValueError, "lock"):
            release.check_release(self.root)

    def test_bump_sets_both_versions_and_engine_requirement(self):
        release.set_version(self.root, "0.3.1")
        for directory in ("python", "tui"):
            content = (self.root / "bindings" / directory / "pyproject.toml").read_text()
            self.assertIn('version = "0.3.1"', content)
        self.assertIn('pytauargus==0.3.1', content)
        self.assertIn('textual>=0.50', content)

    def test_invalid_version_does_not_modify_projects(self):
        path = self.root / "bindings/python/pyproject.toml"
        original = path.read_text()
        with self.assertRaises(ValueError):
            release.set_version(self.root, '0.3.1"\nmalformed')
        self.assertEqual(path.read_text(), original)


if __name__ == "__main__":
    unittest.main()
