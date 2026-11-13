pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../shell/osd/OsdStyles.js" as OsdStyles

// Card picture of an OSD style (layout.osd.style): the real style
// component (loaded by URL, like the stage's) showing a volume level over
// your wallpaper; "in the bar" draws a bar with the level inside its
// controls.
MiniScreen {
    id: root

    property var entry
    property var value: "pill"
    readonly property string style: OsdStyles.normalize(root.value)
    readonly property bool inline: root.style === "bar-inline"
    readonly property var size: OsdStyles.sizeFor(root.style, false, Metrics.osdW)

    Item {
        visible: !root.inline
        width: parent.width
        height: Math.round(parent.height * 0.7)
        Loader {
            id: real
            anchors.centerIn: parent
            width: root.size.w
            height: root.size.h
            scale: Math.min(parent.width * 0.82 / Math.max(1, root.size.w), parent.height * 0.8 / Math.max(1, root.size.h))
            source: root.inline ? "" : "../../shell/osd/" + OsdStyles.fileFor(root.style)
            onLoaded: {
                item.kind = "volume";
                item.value = 0.62;
                item.shown = true;
            }
        }
    }

    // in the bar: the bar along the top, the level inside its controls
    Mark {
        visible: root.inline
        width: parent.width
        height: Math.round(parent.height * 0.22)
        radius: 0
        color: Colors.surfaceContainer
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)
        Mark {
            anchors.right: parent.right
            anchors.rightMargin: parent.height * 0.4
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.42
            height: parent.height * 0.5
            color: Colors.surfaceContainerHighest
            Mark {
                width: parent.width * 0.62
                height: parent.height
                color: Type.progress
            }
        }
    }
}
