import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import "../../../components/kit/KitStates.js" as KitStates

// Small button of the notes editor toolbars with the kit IconButton look
// (KitStates: ghost at rest, hover box, accent tint when `active`): a glyph
// in the icon font, or a styled letter (B / I / U / S) with `glyphFont`.
StyledRect {
    id: button

    property string glyph: ""
    property string glyphFont: Icons.font
    property bool glyphBold: false
    property bool glyphItalic: false
    property bool glyphUnderline: false
    property bool glyphStrikeout: false
    property bool active: false
    property string tooltip: ""
    readonly property string look: KitStates.look(false, button.active, mouseArea.containsMouse)

    signal clicked

    implicitWidth: Space.controlS
    implicitHeight: Space.controlS
    variant: KitStates.variant(button.look, "transparent")
    backgroundOpacity: KitStates.opacity(button.look, mouseArea.containsMouse)
    enableBorder: false
    radius: Look.buttonRadius(height)

    Text {
        anchors.centerIn: parent
        text: button.glyph
        font.family: button.glyphFont
        font.pixelSize: button.glyphFont === Icons.font ? Type.iconSize("body") : Type.size("body")
        font.bold: button.glyphBold
        font.italic: button.glyphItalic
        font.underline: button.glyphUnderline
        font.strikeout: button.glyphStrikeout
        color: KitStates.ink(button.look) === "accent" ? Type.accent : Type.text
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    StyledToolTip {
        tooltipText: button.tooltip
        visible: mouseArea.containsMouse
    }
}
