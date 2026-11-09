pragma ComponentBehavior: Bound

import QtQuick
import "../Ui.js" as Ui

// One window of a preset miniature (PresetMiniShell): shadow, the
// compositor border (focused / inactive colour), a title line, text lines
// and, when focused, two buttons. Drawn in the preset's palette (`shell.c`)
// and scale (`shell.u`), not in the live kit: it pictures another look.
Item {
    id: win

    required property var shell
    property real winRadius: 0
    property real border: 0
    property bool focused: false
    property int lines: 4

    Rectangle {
        visible: win.shell.v("compositor.shadowEnabled", true)
        anchors.fill: parent
        anchors.topMargin: 3 * win.shell.u
        anchors.leftMargin: win.shell.u
        anchors.rightMargin: -win.shell.u
        anchors.bottomMargin: -5 * win.shell.u
        radius: win.winRadius
        color: Ui.alpha(win.shell.c("shadow"), 0.28)
    }
    Rectangle {
        anchors.fill: parent
        radius: win.winRadius
        color: Ui.alpha(win.shell.c("surfaceContainerLow"), win.shell.glass ? 0.84 : 1)
        border.width: win.border
        border.color: win.focused ? win.shell.borderColor(win.shell.v("compositor.activeBorderColor", ["primary"]), "primary") : win.shell.borderColor(win.shell.v("compositor.inactiveBorderColor", ["surface"]), "surface")

        Column {
            x: 12 * win.shell.u + win.border
            y: 12 * win.shell.u + win.border
            width: parent.width - 2 * x
            spacing: 8 * win.shell.u
            Rectangle {
                width: parent.width * 0.45
                height: 9 * win.shell.u
                radius: height / 2
                color: win.shell.c("overBackground")
                opacity: 0.85
            }
            Repeater {
                model: win.lines
                Rectangle {
                    required property int index
                    width: parent.width * (0.9 - (index % 3) * 0.17)
                    height: 6 * win.shell.u
                    radius: height / 2
                    color: win.shell.c("overSurfaceVariant")
                    opacity: 0.45
                }
            }
            Row {
                visible: win.focused
                spacing: 6 * win.shell.u
                Rectangle {
                    width: 46 * win.shell.u
                    height: 16 * win.shell.u
                    radius: Math.min(height / 2, win.shell.radius)
                    color: win.shell.c("primary")
                }
                Rectangle {
                    width: 34 * win.shell.u
                    height: 16 * win.shell.u
                    radius: Math.min(height / 2, win.shell.radius)
                    color: win.shell.c("secondaryContainer")
                }
            }
        }
    }
}
