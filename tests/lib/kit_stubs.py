"""Light stubs of the shared kit (modules/components/kit) for QML tests
that stub the theme: same public API (properties, signals, default
content) without the real theme singletons. `install(h)` registers
`qs.modules.components.kit` in a Harness. tests/kit.test.py covers the
real components."""

SPACE = """pragma Singleton
QtObject {
    property int xs: 4; property int s: 8; property int m: 12; property int l: 16; property int xl: 24; property int xxl: 32
    property int surfaceRadius: 16; property int controlRadius: 12; property int smallRadius: 8
    property int controlS: 36; property int controlM: 40; property int chip: 32; property int keyHint: 20
    property int rowHeight: 48; property int stroke: 3; property int hairline: 1
    function px(v) { return Math.round(v) }
    function round(h) { return h / 2 }
    function clampRadius(r, h) { return Math.min(r, h / 2) }
}"""

TYPE = """pragma Singleton
QtObject {
    property color text: "white"; property color secondary: "silver"; property color muted: "gray"
    property color hairline: "#222222"; property color track: "#333333"; property color placeholder: "#111111"
    readonly property color accentInk: Qt.color("black")
    property color accent: "pink"
    function size(r) { return 14 } function weight(r) { return Font.Normal } function family(r) { return "Sans" }
    function color(r) { return text } function letterSpacing(r) { return 0 } function capitalization(r) { return Font.MixedCase }
    function iconSize(r) { return 16 }
}"""

LOOK = """pragma Singleton
QtObject {
    property string language: "ink"
    property bool dividers: true; property bool groupDivider: true; property bool groupBoxed: false
    property int groupRadius: 0; property int groupPadding: 0; property int groupGap: 16; property int surfacePadding: 16
    property bool boxedControls: false; property bool solidActive: false; property bool squareControls: false
    property int labelWeight: Font.Normal; property int activeLabelWeight: Font.Medium
    function controlFill(h) { return "transparent" }
    function buttonRadius(h) { return h / 2 } function chipRadius(h) { return Math.min(12, h / 2) }
}"""

TYPES = {
    "Space": SPACE,
    "Type": TYPE,
    "Look": LOOK,
    "KitText": "Text { property string role: 'body'; property bool tabular: false; elide: Text.ElideRight }",
    "SectionLabel": "Item { property string text; property string action; signal triggered; implicitHeight: 14 }",
    "Divider": "Item { property bool vertical: false; implicitHeight: 1 }",
    "Group": "Column { property string label; property string actionText; property bool divider: false; "
             "property int padding: 0; signal actionTriggered; spacing: 12 }",
    "IconButton": "Item { property string icon; property string size: 'm'; property bool active: false; "
                  "property bool primary: false; property bool highlighted: false; signal clicked; "
                  "implicitWidth: size === 's' ? 36 : 40; implicitHeight: implicitWidth }",
    "Chip": "Item { property string icon; property string text; property bool active: false; "
            "property bool highlighted: false; signal clicked; implicitWidth: 60; implicitHeight: 32 }",
    "ListRow": "Item { id: r; property string title; property string subtitle; property bool selected; "
               "property bool highlighted; property bool tabular; property Component leading: null; "
               "property Component trailing: null; signal clicked; implicitHeight: 48; implicitWidth: 200\n"
               "Row { anchors.fill: parent; Loader { active: r.leading !== null; sourceComponent: r.leading } "
               "Loader { active: r.trailing !== null; sourceComponent: r.trailing } } }",
    "ProgressLine": "Item { property real value: 0; implicitWidth: 160; implicitHeight: 3 }",
    "Ring": "Item { property real value: 0; property real thickness: 3; property color color: 'pink'; "
            "implicitWidth: 64; implicitHeight: 64 }",
    "KeyHint": "Item { property string text; property string icon; implicitWidth: 20; implicitHeight: 20 }",
    "Art": "Item { property url source; property string icon; property string placeholderText; property real radius; "
           "property int fillMode; implicitWidth: 40; implicitHeight: 40 }",
    "Avatar": "Item { property url source; property string icon; property string name; property real radius; "
              "implicitWidth: 40; implicitHeight: 40 }",
    "LineSlider": "Item { property real from: 0; property real to: 1; property real value: 0; property string icon; "
                  "signal moved(real value) }",
    "Surface": "Item { property int padding: 16 }",
}


def install(h) -> None:
    h.module("qs.modules.components.kit", TYPES)


def files() -> dict:
    """{TypeName: full QML source} for harnesses that write raw files."""
    out = {}
    for name, body in TYPES.items():
        if body.startswith("pragma Singleton"):
            out[name] = body.replace("pragma Singleton\n", "pragma Singleton\nimport QtQuick\n", 1)
        else:
            out[name] = "import QtQuick\n" + body
    return out
