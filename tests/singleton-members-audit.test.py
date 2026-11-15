"""The singleton-members audit reports `Look.x` (and the other listed kit /
theme singletons) where x is not declared by the singleton."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks import singleton_members as S  # noqa: E402
from lib.model import load_config  # noqa: E402

LOOK = """pragma Singleton
import QtQuick
// readonly property int commented: 1
QtObject {
    id: root
    readonly property real boxPadding: 4
    property var spec: ({})
    required property int need
    function radius(role, h) { return 0; }
    signal changedLook
}
"""
known = {"Look": S.members_of(LOOK)}
assert {"boxPadding", "spec", "need", "radius", "changedLook", "boxPaddingChanged", "objectName"} <= known["Look"], known
assert "commented" not in known["Look"], known

USER = """import QtQuick
Item {
    width: Look.boxPadding + Look.radius("box", 4)
    height: Look.cardRowHeight
    // Look.inComment
    property string s: "Look.inString"
    property int e: Look.SomeEnum
    property var x: FittedLook.whatever + root.Look.nested
    onWidthChanged: Look.boxPaddingChanged.connect(f)
}
"""
got = S.unknown_uses(USER, known)
assert got == [(4, "Look", "cardRowHeight")], got

# the real tree is clean, and every configured singleton file exists
defs = load_config()["singletonMembers"]["singletons"]
assert "Look" in defs and all((REPO / f).is_file() for f in defs.values()), defs
issues = S.run(load_config())
assert not issues, [i.to_dict() for i in issues]
print("PASS singleton-members-audit")
