import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Square button of the notes editor toolbars: a glyph (icon font or styled
// letter), hover surface, optional "active" state and a tooltip.
Rectangle {
    id: button

    property string glyph: ""
    property string glyphFont: Icons.font
    property int glyphSize: 14
    property bool glyphBold: false
    property bool glyphItalic: false
    property bool glyphUnderline: false
    property bool glyphStrikeout: false
    property bool active: false
    property string tooltip: ""

    signal clicked

    width: 32
    height: 32
    radius: Styling.radius(-4)
    color: button.active ? Styling.srItem("overprimary") : "transparent"

    StyledRect {
        anchors.fill: parent
        variant: mouseArea.containsMouse && !button.active ? "surface" : "transparent"
        radius: Styling.radius(-4)
        visible: !button.active
    }

    Text {
        anchors.centerIn: parent
        text: button.glyph
        font.family: button.glyphFont
        font.pixelSize: button.glyphSize
        font.bold: button.glyphBold
        font.italic: button.glyphItalic
        font.underline: button.glyphUnderline
        font.strikeout: button.glyphStrikeout
        color: button.active ? Colors.overPrimary : Colors.overSurface
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
