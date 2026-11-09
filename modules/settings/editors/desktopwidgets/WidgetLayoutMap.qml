pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.desktop.widgets
import "../../../desktop/widgets/WidgetRegistry.js" as Registry
import "../../Ui.js" as Ui
import qs.modules.components.kit

// Miniature of one screen: where its widgets sit and the depth clock's
// area (widgets over it hide the clock).
Item {
    id: root

    property string screenName: ""
    property real screenW: 2560
    property real screenH: 1440
    property var widgets: []
    property string wallpaper: ""

    readonly property real s: Math.min(width / screenW, height / screenH)
    readonly property var clockArea: DesktopWidgets.clockArea(screenName)

    Rectangle {
        id: screen
        width: root.screenW * root.s
        height: root.screenH * root.s
        anchors.centerIn: parent
        radius: Math.min(Styling.radius(0), 10)
        color: Colors.surfaceContainerLowest
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.8)
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: Space.hairline
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 480
            opacity: 0.75
        }

        Rectangle {
            visible: root.clockArea !== null
            x: (root.clockArea?.x ?? 0) * root.s
            y: (root.clockArea?.y ?? 0) * root.s
            width: (root.clockArea?.w ?? 0) * root.s
            height: (root.clockArea?.h ?? 0) * root.s
            radius: 4
            color: Ui.alpha(Colors.tertiary, 0.18)
            border.width: 1
            border.color: Colors.tertiary
        }

        Repeater {
            model: root.widgets
            Rectangle {
                id: box
                required property var modelData
                readonly property var type: Registry.get(modelData.type)
                x: modelData.x * screen.width
                y: modelData.y * screen.height
                width: modelData.w * screen.width
                height: modelData.h * screen.height
                radius: Math.min(6, height / 4)
                color: Ui.alpha(Colors.primary, 0.32)
                border.width: 1
                border.color: Colors.primary

                Icon {
                    anchors.centerIn: parent
                    icon: Icons[box.type?.icon ?? ""] ?? ""
                    tone: "text"
                    size: Math.max(Type.size("label") - Space.xs, Math.min(Type.iconSize("caption"), box.height * 0.5))
                }
            }
        }
    }

    KitText {
        role: "caption"
        anchors.left: screen.left
        anchors.top: screen.bottom
        anchors.topMargin: Space.xs
        text: root.screenName
        color: Colors.overSurfaceVariant
    }
}
