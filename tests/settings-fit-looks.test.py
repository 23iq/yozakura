"""Settings layout probes in every visual language, part 1 of
fit_looks.PARTS (tests/lib/fit_looks.py says what is checked)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import fit_looks  # noqa: E402

fit_looks.run("settings-fit-looks", 0)
