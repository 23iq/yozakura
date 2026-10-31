pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

// The palette subset the wallpaper tint shaders map colours to, as a 1 px
// tall texture (`texture`, `size` entries). Same roles as StaticWallpaper's
// `optimizedPalette`. Only built while `active`.
Item {
    id: root

    property bool active: false
    readonly property var roles: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
    readonly property int size: roles.length
    readonly property alias texture: textureSource

    width: 0
    height: 0

    Item {
        id: strip
        visible: root.active
        width: root.roles.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: root.active ? root.roles : []
                Rectangle {
                    required property string modelData
                    width: 1
                    height: 1
                    color: Colors[modelData]
                }
            }
        }
    }

    ShaderEffectSource {
        id: textureSource
        sourceItem: root.active ? strip : null
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }
}
