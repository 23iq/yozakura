"""Self-test for tests/lib/qmlharness.py (dependency copying and auto-stubbing)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("selftest")

# copy() brings relative JS imports along.
colors = h.copy("modules/theme/Colors.qml", strip_singleton=True, siblings=False)
assert (colors.parent / "ColorUtils.js").is_file(), "relative JS import must be copied"

# Unknown types, their properties and signal handlers are stubbed on demand.
obj = h.load("""
import QtQuick
import some.missing.module
Item {
    property int seen: 0
    NotARealType { id: fake; answer: 42; onPinged: parent.seen++ }
}
""")
assert obj is not None
assert "NotARealType" in h.auto_stubs, h.auto_stubs
assert "NotARealType.answer" in h.auto_stubs and "NotARealType.onPinged" in h.auto_stubs, h.auto_stubs
assert "module some.missing.module" in h.auto_stubs, h.auto_stubs
assert h.eval(obj, "fake.answer") == 42

# Stub modules: singleton bodies may omit the boilerplate.
h.singleton("qs.example", "Answer", "QtObject { property int value: 7 }")
assert h.eval(h.load("import qs.example\nItem { property int v: Answer.value }"), "v") == 7

# Strict mode refuses to fake anything.
try:
    h.load("Item { AlsoMissing {} }", auto_stub=False)
except AssertionError as e:
    assert "AlsoMissing is not a type" in str(e), e
else:
    raise AssertionError("auto_stub=False must fail on unknown types")

# Types that exist in the repo are never faked: a resolution failure is real.
try:
    h.load("Item { ClockHalo {} }")
except AssertionError as e:
    assert "exists in the repo" in str(e) and "ClockHalo.qml" in str(e), e
else:
    raise AssertionError("auto-stubbing a repo type must fail loudly")

# Runtime type errors (Loader, deferred layer.effect) are recorded; the
# process would exit non-zero at the end unless explicitly allowed.
broken = h.write("Item { layer.enabled: true; layer.effect: MissingEffect {} }", name="Broken.qml")
h.load(f'Item {{ Loader {{ source: "{broken.name}" }} }}')
from PySide6.QtCore import QCoreApplication  # noqa: E402
QCoreApplication.processEvents()
assert any("MissingEffect" in m for m in h.type_errors), h.type_errors
h.allow_type_errors = True

print("qmlharness: PASS")
