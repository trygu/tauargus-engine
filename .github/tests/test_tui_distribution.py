import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from zipfile import ZipFile


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check_tui_dist.py"
spec = importlib.util.spec_from_file_location("check_tui_dist", SCRIPT)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dist = Path(self.tmp.name)

    def make_distribution(self, *, name="pytauargus-tui", dependency="pytauargus>=0.3.0",
                          payload=None, wheel_tag="py3-none-any", entry_point=True):
        metadata = (f"Metadata-Version: 2.4\nName: {name}\nVersion: 0.1.0\n"
                    f"Requires-Dist: {dependency}\nRequires-Dist: textual>=0.50\n")
        wheel = self.dist / f"pytauargus_tui-0.1.0-{wheel_tag}.whl"
        info = "pytauargus_tui-0.1.0.dist-info/"
        with ZipFile(wheel, "w") as archive:
            archive.writestr(info + "METADATA", metadata)
            archive.writestr(info + "WHEEL", f"Root-Is-Purelib: true\nTag: {wheel_tag}\n")
            if entry_point:
                archive.writestr(info + "entry_points.txt",
                                 "[console_scripts]\ntauargus-tui = pytauargus_tui.app:main\n")
            archive.writestr("pytauargus_tui/__init__.py", "")
            if payload:
                archive.writestr(payload, "")
        data = metadata.encode()
        with tarfile.open(self.dist / "pytauargus_tui-0.1.0.tar.gz", "w:gz") as archive:
            member = tarfile.TarInfo("pytauargus_tui-0.1.0/PKG-INFO")
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))

    def test_separate_portable_package(self):
        self.make_distribution()
        checker.check_distribution(self.dist, "0.1.0", "py-v0.1.0")

    def test_wrong_release_tag(self):
        self.make_distribution()
        with self.assertRaisesRegex(ValueError, "tag"):
            checker.check_distribution(self.dist, "0.1.0", "py-v0.2.0")

    def test_core_package_cannot_be_published_as_tui(self):
        self.make_distribution(name="pytauargus")
        with self.assertRaisesRegex(ValueError, "name"):
            checker.check_distribution(self.dist, "0.1.0")

    def test_native_library_leak(self):
        self.make_distribution(payload="pytauargus_tui/libtauargus.dylib")
        with self.assertRaisesRegex(ValueError, "native"):
            checker.check_distribution(self.dist, "0.1.0")

    def test_core_code_leak(self):
        self.make_distribution(payload="pytauargus/engine.py")
        with self.assertRaisesRegex(ValueError, "core"):
            checker.check_distribution(self.dist, "0.1.0")

    def test_local_development_dependency_cannot_ship(self):
        self.make_distribution(dependency="pytauargus @ file:///checkout/bindings/python")
        with self.assertRaisesRegex(ValueError, "dependency"):
            checker.check_distribution(self.dist, "0.1.0")

    def test_platform_specific_wheel(self):
        self.make_distribution(wheel_tag="cp313-cp313-macosx_14_0_arm64")
        with self.assertRaisesRegex(ValueError, "portable"):
            checker.check_distribution(self.dist, "0.1.0")

    def test_missing_console_command(self):
        self.make_distribution(entry_point=False)
        with self.assertRaisesRegex(ValueError, "entry point"):
            checker.check_distribution(self.dist, "0.1.0")
