import QtQuick

// Status chip (user, keyboard layout, session, power) drawn in the active
// style's chip look (SddmStyle.chip* properties).
Rectangle {
    id: chip

    required property Item look
    property string glyph: ""
    property string label: ""
    property string glyphFont: ""
    property color glyphColor: look.chipInk
    property bool caret: false
    property string caretGlyph: ""
    property bool active: false
    property alias leading: leadingSlot.data
    readonly property bool hovered: chipMouse.containsMouse
    readonly property color ink: look.chipInk
    signal clicked

    height: 36
    width: chipRow.implicitWidth + (leadingSlot.children.length > 0 ? 4 + 16 : (label === "" ? 0 : 32))
    implicitWidth: width
    radius: (height / 2) * look.chipRoundness
    color: look.chipFill
    border.width: look.chipBorderWidth
    border.color: active ? Qt.rgba(ink.r, ink.g, ink.b, 0.45) : (hovered ? Qt.rgba(ink.r, ink.g, ink.b, 0.3) : look.chipBorder)
    antialiasing: true

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: chip.ink
        opacity: chip.active ? 0.10 : (chip.hovered ? 0.06 : 0)
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    Row {
        id: chipRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: leadingSlot.children.length > 0 ? parent.left : undefined
        anchors.leftMargin: 4
        anchors.horizontalCenter: leadingSlot.children.length > 0 ? undefined : parent.horizontalCenter
        spacing: chip.label === "" ? 0 : (leadingSlot.children.length > 0 ? 10 : 8)

        Item {
            id: leadingSlot
            width: children.length > 0 ? 28 : 0
            height: 28
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.glyph !== ""
            width: chip.label === "" ? 36 : implicitWidth
            horizontalAlignment: Text.AlignHCenter
            text: chip.glyph
            font.family: chip.glyphFont
            font.pixelSize: 16
            color: chip.glyphColor
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.label !== ""
            text: chip.label
            font.family: chip.look.chipFont
            font.pixelSize: chip.look.chipFontSize
            font.weight: Font.DemiBold
            font.letterSpacing: chip.look.chipLetterSpacing
            font.capitalization: chip.look.chipCaps ? Font.AllUppercase : Font.MixedCase
            color: chip.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: chip.caret
            text: chip.caretGlyph
            font.family: chip.glyphFont
            font.pixelSize: 12
            color: chip.ink
            opacity: 0.6
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
