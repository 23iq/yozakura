pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.config

// Flat icon button used across the AI center (hover/active states use the
// "focus"/"primary" variants so every preset styles it).
Button {
    id: root

    property string glyph: ""
    property string tooltip: ""
    property bool active: false
    property bool danger: false
    property int size: 30
    property int iconSize: 15

    implicitWidth: size
    implicitHeight: size
    flat: true
    padding: 0
    focusPolicy: Qt.NoFocus

    background: StyledRect {
        variant: root.active ? "primary" : (root.danger && root.hovered ? "error" : "focus")
        radius: Styling.radius(-4)
        opacity: root.active ? 1 : (root.down ? 1 : (root.hovered ? 0.85 : 0))
        enableBorder: false
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 4
            }
        }
    }

    contentItem: Text {
        text: root.glyph
        font.family: Icons.font
        font.pixelSize: root.iconSize
        color: root.active ? Styling.srItem("primary") : (root.danger && root.hovered ? Styling.srItem("error") : Colors.overSurface)
        opacity: root.enabled ? 1 : 0.4
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    StyledToolTip {
        tooltipText: root.tooltip
        show: root.hovered && root.tooltip.length > 0
    }
}
