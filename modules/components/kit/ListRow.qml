import QtQuick
import QtQuick.Layouts
import qs.modules.components
import "KitStates.js" as KitStates
import qs.modules.components.kit

// One row of a list: a leading slot (icon / Avatar / Art), a title with an
// optional one-line subtitle (elided) and a trailing slot. Rows are ghosts
// at rest (the surface is the box); hover / `highlighted` (keyboard cursor)
// show the language's hover box (Look), `selected` the accent tint. Height:
// Metrics.rowHeight.
StyledRect {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property bool highlighted: false
    // Tabular figures in the title (times, counters)
    property bool tabular: false
    // The title drawn in another family (font pickers); "" = the body font
    property string titleFamily: ""
    property Component leading: null
    property Component trailing: null
    readonly property bool hovered: mouse.containsMouse || root.highlighted
    readonly property string look: KitStates.look(false, root.selected, root.hovered && root.enabled)
    readonly property bool boxed: Look.boxedControls && root.look === "hover"

    signal clicked
    signal doubleClicked

    implicitHeight: Space.rowHeight
    implicitWidth: row.implicitWidth + Space.s * 2
    variant: KitStates.variant(root.look, "transparent")
    backgroundOpacity: root.boxed ? 0 : KitStates.opacity(root.look, root.hovered)
    enableBorder: false
    radius: Look.chipRadius(height)
    opacity: root.enabled ? 1 : 0.38

    Accessible.role: Accessible.ListItem
    Accessible.name: root.title
    Accessible.selected: root.selected

    ControlBox {
        shown: root.boxed
        radius: root.radius
        hovered: true
        border.width: 0
    }

    // Under the row: trailing controls get their own clicks.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
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
                tabular: root.tabular
                text: root.title
                font.weight: Look.labelWeight
                font.family: root.titleFamily !== "" ? root.titleFamily : Type.family("body")
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
