pragma ComponentBehavior: Bound
import QtQuick

// Drop-down list (sessions, users, keyboard layouts) in the style's look.
Rectangle {
    id: menu

    required property Item look
    property var entries: []
    property int currentIndex: -1
    property real maxEntryWidth: 0
    readonly property color ink: look.chipInk
    signal picked(int index)

    onEntriesChanged: maxEntryWidth = 0
    width: Math.max(200, maxEntryWidth + 32 + 12)
    height: menuColumn.implicitHeight + 12
    radius: Math.min(22, 18 * look.chipRoundness + 6 * Math.min(1, look.chipRoundness * 4))
    color: look.menuFill
    border.width: look.chipBorderWidth
    border.color: look.chipBorder
    antialiasing: true

    // Swallow clicks so they don't reach the background closer.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: menuColumn
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 2
        Repeater {
            model: menu.entries
            delegate: Rectangle {
                id: entry
                required property int index
                required property string modelData
                readonly property bool selected: index === menu.currentIndex
                width: menuColumn.width
                height: 36
                radius: (height / 2) * menu.look.chipRoundness
                color: selected ? menu.look.accent : (entryMouse.containsMouse ? Qt.rgba(menu.ink.r, menu.ink.g, menu.ink.b, 0.08) : "transparent")
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: entry.modelData
                    font.family: menu.look.chipFont
                    font.pixelSize: menu.look.chipFontSize + 1
                    font.weight: entry.selected ? Font.DemiBold : Font.Normal
                    color: entry.selected ? menu.look.overAccent : menu.ink
                    onImplicitWidthChanged: menu.maxEntryWidth = Math.max(menu.maxEntryWidth, implicitWidth)
                    Component.onCompleted: menu.maxEntryWidth = Math.max(menu.maxEntryWidth, implicitWidth)
                }
                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.picked(entry.index)
                }
            }
        }
    }
}
