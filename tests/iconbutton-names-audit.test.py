"""The iconbutton-names audit reports a kit IconButton that sets neither
`accessibleName`, `tooltip`, `Accessible.name` nor `Accessible.ignored`
(a screen reader would announce a nameless button)."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks import iconbutton_names as N  # noqa: E402
from lib.model import load_config  # noqa: E402

QML = """import QtQuick
Row {
    // IconButton { icon: "in a comment" }
    property string s: "IconButton { in a string }"
    IconButton {
        icon: Icons.cancel
        Item {
            property string tooltip: "a nested object's tooltip does not count"
        }
    }
    IconButton { tooltip: I18n.t("common.close") }
    IconButton {
        accessibleName: I18n.t("common.remove")
        onClicked: { if (x) { y(); } }
    }
    IconButton {
        Accessible.name: "Play"
    }
    IconButton {
        Accessible.ignored: true
    }
    delegate: IconButton {
        icon: modelData
    }
}
"""
got = N.nameless(QML)
assert got == [5, 22], got

# the real tree is clean
issues = N.run(load_config())
assert not issues, [i.to_dict() for i in issues]
print("PASS iconbutton-names-audit")
