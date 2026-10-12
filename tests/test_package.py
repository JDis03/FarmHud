"""Offline unit tests of the packaging tool; no downloads or game files."""
import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location(
    "package_forever", Path(__file__).resolve().parents[1] / "tools/package_forever.py"
)
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        for directory in ("media", "modules"):
            (self.repo / directory).mkdir()
        (self.repo / "FarmHud.toc").write_text("## Version: @project-version@\nFarmHud.xml\n")
        (self.repo / "FarmHud.xml").write_text(
            '<Ui><!--@do-not-package@--><Script file="dev.lua"/>'
            '<!--@end-do-not-package@--><Script file="FarmHud_Compat.lua"/></Ui>'
        )
        (self.repo / "FarmHud_Compat.lua").write_text('local version="@project-version@"\n')
        (self.repo / "README.md").write_text("readme\n")
        (self.repo / "LICENSE").write_text("license\n")
        self.source = self.root / "upstream.zip"
        self.output = self.root / "out.zip"
        self.make_source()

    def make_source(self, unsafe=False):
        with zipfile.ZipFile(self.source, "w") as archive:
            archive.writestr("FarmHud/libs/LibStub/LibStub.lua", "-- audited library\n")
            archive.writestr("FarmHud/FarmHud.lua", "-- must not replace fork source\n")
            if unsafe:
                archive.writestr("FarmHud/libs/../../escape.lua", "-- unsafe\n")

    def run_builder(self, output=None, checksum=None):
        checksum = checksum or hashlib.sha256(self.source.read_bytes()).hexdigest()
        with patch.object(builder, "ROOT", self.repo), patch.object(builder, "UPSTREAM_SHA256", checksum), \
                patch("sys.argv", ["package_forever.py", str(self.source), str(output or self.output)]), \
                contextlib.redirect_stdout(io.StringIO()):
            builder.main()

    def test_package_uses_fork_and_pinned_libraries(self):
        self.run_builder()
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertNotIn("FarmHud/FarmHud.lua", archive.namelist())
            self.assertIn("FarmHud/libs/LibStub/LibStub.lua", archive.namelist())
            self.assertIn(builder.VERSION, archive.read("FarmHud/FarmHud.toc").decode())
            xml = archive.read("FarmHud/FarmHud.xml").decode()
            self.assertNotIn("dev.lua", xml)
            self.assertIn("FarmHud_Compat.lua", xml)
        second = self.root / "second.zip"
        self.run_builder(second)
        self.assertEqual(self.output.read_bytes(), second.read_bytes())

    def test_bad_checksum_rejected_without_output(self):
        with self.assertRaisesRegex(SystemExit, "SHA-256"):
            self.run_builder(checksum="0" * 64)
        self.assertFalse(self.output.exists())

    def test_existing_output_preserved(self):
        self.output.write_bytes(b"keep existing output")
        with self.assertRaisesRegex(SystemExit, "already exists"):
            self.run_builder()
        self.assertEqual(self.output.read_bytes(), b"keep existing output")

    def test_path_traversal_rejected_without_output(self):
        self.make_source(unsafe=True)
        with self.assertRaisesRegex(SystemExit, "Unsafe"):
            self.run_builder()
        self.assertFalse(self.output.exists())

    def test_lua_development_block_removed(self):
        self.assertEqual(builder.preprocess("if ok then\n--@do-not-package@\nelse debug()\n--@end-do-not-package@\nend"),
                         "if ok then\n\nend")


if __name__ == "__main__":
    unittest.main()
