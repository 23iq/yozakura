"""Bundled UI fonts load into the Qt font database under their registered family.

Registers every file of modules/theme/BundledFonts.js with QFontDatabase
(what FontRegistry.qml's FontLoaders do) and checks the family name a
preset writes is the one the file provides.
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import headless  # noqa: E402

headless.ensure()
from PySide6.QtGui import QFontDatabase, QGuiApplication  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
script = ("const q=require(process.argv[1]);const f=q.loadLibrary(process.argv[2]);"
          "console.log(JSON.stringify(f.FONTS.map(x=>({family:x.family,files:x.files.map(n=>f.ROOT+x.dir+'/'+n)}))))")
fonts = json.loads(subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"),
                                   str(REPO / "modules/theme/BundledFonts.js")],
                                  capture_output=True, text=True, check=True).stdout)
app = QGuiApplication([])
failures = []
for entry in fonts:
    for f in entry["files"]:
        fid = QFontDatabase.addApplicationFont(str(REPO / f))
        fams = QFontDatabase.applicationFontFamilies(fid) if fid >= 0 else []
        if entry["family"] not in fams:
            failures.append(f"{f}: registers {fams}, expected {entry['family']!r}")
for msg in failures:
    print("FAIL", msg)
print(f"{sum(len(e['files']) for e in fonts)} files, {len(failures)} failures")
sys.exit(1 if failures else 0)
