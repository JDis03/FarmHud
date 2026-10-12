#!/usr/bin/env python3
"""Package this fork with the audited upstream 10.3.0 libraries, offline.

Usage: python3 tools/package_forever.py <FarmHud-10.3.0-release.zip> <output.zip>
No game files are read or written. The upstream archive must match its pinned
SHA-256; only its libs/ entries are used. No mutable dependency downloads.
"""
import hashlib
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

UPSTREAM_SHA256 = "2830078435bf7e827b2a0ea8526a0f3939c2dee16f00bc77768b3acb8368ecb0"
VERSION = "10.3.0-forever.1"
ROOT = Path(__file__).resolve().parents[1]


def preprocess(text):
    text = re.sub(r"<!--@do-not-package@-->.*?<!--@end-do-not-package@-->", "", text, flags=re.S)
    text = re.sub(r"--@do-not-package@.*?--@end-do-not-package@", "", text, flags=re.S)
    return text.replace("@project-version@", VERSION)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source, output = map(Path, sys.argv[1:])
    if hashlib.sha256(source.read_bytes()).hexdigest() != UPSTREAM_SHA256:
        raise SystemExit("Unexpected upstream archive SHA-256; libraries were not audited")
    if output.exists():
        raise SystemExit("Output already exists; choose a new path")
    entries = {}
    with zipfile.ZipFile(source) as archive:
        for info in archive.infolist():
            path = PurePosixPath(info.filename)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit("Unsafe upstream archive path")
            if info.filename.startswith("FarmHud/libs/") and not info.is_dir():
                entries[info.filename] = archive.read(info)
    if "FarmHud/libs/LibStub/LibStub.lua" not in entries:
        raise SystemExit("Upstream libraries are missing")
    files = [p for p in ROOT.iterdir() if p.suffix in (".lua", ".xml", ".toc")]
    for directory in ("media", "modules"):
        files.extend(p for p in (ROOT / directory).rglob("*") if p.is_file())
    files.extend(ROOT / name for name in ("README.md", "LICENSE"))
    for path in files:
        data = path.read_bytes()
        if path.suffix in (".lua", ".xml", ".toc"):
            data = preprocess(data.decode("utf-8")).encode("utf-8")
        entries["FarmHud/" + path.relative_to(ROOT).as_posix()] = data
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(entries.items()):
            # Fixed metadata makes the output deterministic with the same tools.
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    print(str(output) + ": " + str(len(entries)) + " files, version " + VERSION)


if __name__ == "__main__":
    main()
