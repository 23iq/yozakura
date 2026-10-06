import QtQuick
import QtQuick.Layouts
import qs.modules.components
import "KitStates.js" as KitStates

// One row of a list: a leading slot (icon / Avatar / Art), a title with an
// optional one-line subtitle (elided) and a trailing slot. Rows are ghosts
// at rest (the surface is the box); hover / `highlighted` (keyboard cursor)
// show the focus look, `selected` the accent tint. Height: Metrics.rowHeight.
StyledRect {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property bool highlighted: false
    property Component leading: null
    property Component trailing: null
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property string look: KitStates.look(false, root.selected, root.hovered && root.enabled)

    signal clicked

    implicitHeight: Space.rowHeight
    implicitWidth: row.implicitWidth + Space.s * 2
    variant: KitStates.variant(root.look, "transparent")
    backgroundOpacity: KitStates.opacity(root.look, root.hovered)
    enableBorder: false
    radius: Space.clampRadius(Space.controlRadius, height)
    opacity: root.enabled ? 1 : 0.38

    Accessible.role: Accessible.ListItem
    Accessible.name: root.title
    Accessible.selected: root.selected

    // Under the row: trailing controls get their own clicks.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.m

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
            Layout.alignment: Qt.AlignVCenter
        }

        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            KitText {
                width: parent.width
                role: "body"
                text: root.title
            }

            KitText {
                width: parent.width
                visible: root.subtitle !== ""
                role: "secondary"
                text: root.subtitle
                maximumLineCount: 1
            }
        }

        Loader {
            active: root.trailing !== null
            visible: active
            sourceComponent: root.trailing
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
