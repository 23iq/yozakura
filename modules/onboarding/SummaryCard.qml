import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// One entry of the setup summary (a cell of the summary Group): the area's
// icon, its label and the value; `busy` adds a live ProgressLine under the
// value (installs still running; `percent` < 0 = unknown, it sweeps).
// Static on purpose: a ListRow would hover like something to click.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property bool busy: false
    property int percent: -1
    property bool muted: false

    implicitHeight: Math.max(Space.rowHeight, texts.implicitHeight + Space.s * 2)

    Text {
        id: glyph
        x: Space.s
        anchors.verticalCenter: parent.verticalCenter
        width: Type.iconSize("title")
        horizontalAlignment: Text.AlignHCenter
        text: Icons[root.icon] ?? ""
        font.family: Icons.font
        font.pixelSize: Type.iconSize("body")
        color: root.muted ? Type.muted : Type.secondary
    }

    Column {
        id: texts
        anchors.left: glyph.right
        anchors.leftMargin: Space.m
        anchors.right: parent.right
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        KitText {
            width: parent.width
            role: "caption"
            elide: Text.ElideRight
            text: root.label
        }
        KitText {
            objectName: "value"
            width: parent.width
            role: "body"
            font.weight: Look.labelWeight
            color: root.muted ? Type.secondary : Type.text
            elide: Text.ElideRight
            text: root.value
        }
        Item {
            visible: root.busy
            width: parent.width
            height: Space.s
            ProgressLine {
                objectName: "progress"
                anchors.bottom: parent.bottom
                width: parent.width
                indeterminate: root.percent < 0
                value: root.percent / 100
            }
        }
    }
}
