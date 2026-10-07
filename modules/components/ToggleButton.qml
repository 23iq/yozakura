import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.modules.services
import qs.modules.theme
import qs.modules.globals
import qs.config
import qs.modules.bar.look

Button {
    id: root

    required property string buttonIcon
    required property string tooltipText
    required property var onToggle
    property bool iconTint: false
    property bool iconFullTint: false
    property int iconSize: 18
    property bool enableShadow: true
    // Radius handling
    property real radius: 0
    property bool vertical: false // Set by parent if needed, or inferred? ToggleButton doesn't know orientation usually.
    // We will let parent set start/end radius directly or use radius as fallback
    property real startRadius: radius
    property real endRadius: radius
    // Bar panels: module size; Button.flat drops the pill background
    property int size: BarMetrics.moduleSize

    implicitWidth: size
    implicitHeight: size

    // Check if buttonIcon is a single character (icon font) or a file path
    readonly property bool isIconPath: buttonIcon.length > 1

    // The bar module look (group box piece, hover, pressed = hover)
    background: ModuleBox {
        id: bg
        vertical: root.vertical
        startRadius: root.startRadius
        endRadius: root.endRadius
        flat: root.flat
        shadow: root.enableShadow && Config.showBackground
        hovered: root.hovered || root.pressed
    }

    contentItem: Item {
        // Text icon (single character)
        Text {
            visible: !root.isIconPath
            anchors.fill: parent
            text: root.buttonIcon
            textFormat: Text.RichText
            font.family: Icons.font
            font.pixelSize: BarLook.iconSize(root.size)
            color: bg.ink
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Image icon (SVG/PNG)
        Item {
            id: iconImageContainer
            visible: root.isIconPath
            anchors.centerIn: parent
            readonly property real side: (BarMetrics.compact || root.size < BarMetrics.moduleSize) ? Math.min(root.iconSize, root.size - 8) : root.iconSize
            width: side
            height: side

            Image {
                id: iconImage
                anchors.fill: parent
                source: root.isIconPath ? root.buttonIcon : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
            }

            Tinted {
                anchors.fill: parent
                sourceItem: iconImage
                active: root.iconTint || root.iconFullTint
                fullTint: root.iconFullTint
            }
        }
    }

    onClicked: root.onToggle()

    ToolTip.visible: false
    ToolTip.text: root.tooltipText
    ToolTip.delay: 1000
}
