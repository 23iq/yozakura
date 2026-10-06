import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.services
import qs.modules.shell.osd

// Lives inside the bar's volume/brightness button: on an OSD event the
// button fills like a gauge and shows the level glyph, then settles back.
// Registers with OsdService so the window falls back to the pill when no
// bar widget exists.
Item {
    id: root

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property string device: ""
    property bool vertical: false
    property bool shown: false
    property real radius: 0

    visible: opacity > 0
    opacity: root.shown ? 1 : 0
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? OsdMotion.enterMs : OsdMotion.exitMs
            easing.type: OsdMotion.enterEasing
        }
    }

    StyledRect {
        anchors.fill: parent
        variant: "popup"
        enableBorder: false
        radius: root.radius
    }

    // Gauge: rises from the bottom edge of the button.
    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * root.value
        variant: root.muted && root.kind !== "brightness" ? "common" : "primary"
        enableBorder: false
        radius: root.radius
        opacity: 0.55

        Behavior on height {
            NumberAnimation {
                duration: OsdMotion.enterMs
                easing.type: OsdMotion.enterEasing
            }
        }
    }

    OsdGlyph {
        anchors.centerIn: parent
        font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.5)
        kind: root.kind
        value: root.value
        muted: root.muted
    }

    Timer {
        id: settle
        interval: OsdService.timeout
        onTriggered: root.shown = false
    }

    Connections {
        target: OsdService

        function onInlineRequest(kind) {
            root.kind = kind;
            root.value = OsdService.lastValue;
            root.muted = OsdService.lastMuted;
            root.shown = true;
            settle.restart();
        }

        function onLevel(kind, value, muted, device) {
            if (root.shown) {
                root.value = value;
                root.muted = muted;
            }
        }
    }

    Component.onCompleted: OsdService.registerInline(true)
    Component.onDestruction: OsdService.registerInline(false)
}
