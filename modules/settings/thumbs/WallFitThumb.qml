pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of how the wallpaper fits (desktop.wallpaperMode): fill =
// the picture covers the screen; panorama = one wide picture across the
// workspaces, the screen showing one slice of it (bracketed), the other
// workspaces dashed beside it.
MiniScreen {
    desktop: true
    id: root

    property var entry
    property var value: "fill"
    readonly property bool panorama: root.value === "panorama"

    // Panorama: the picture zoomed so the screen holds a slice of it.
    Item {
        anchors.fill: parent
        visible: root.panorama

        Mark {
            anchors.fill: parent
            radius: 0
            color: Qt.alpha(Colors.shadow, 0.45)
        }
        Repeater {
            model: 3
            delegate: Mark {
                required property int index
                readonly property real w: (root.width - root.u * 8) / 3
                x: root.u * 2 + index * (w + root.u * 2)
                y: root.height * 0.2
                width: w
                height: root.height * 0.52
                radius: root.u * 2
                color: index === 0 ? Qt.alpha(Type.accent, 0.12) : "transparent"
                border.width: index === 0 ? Space.stroke : Space.hairline
                border.color: index === 0 ? Type.accent : Qt.alpha(Type.text, 0.5)
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.78
            spacing: root.u * 2
            Repeater {
                model: 3
                delegate: Mark {
                    required property int index
                    width: index === 0 ? root.u * 6 : root.u * 2
                    height: root.u * 2
                    color: index === 0 ? Type.accent : Qt.alpha(Type.text, 0.6)
                }
            }
        }
    }
}
