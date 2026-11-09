import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.components.kit

// Collapsed-by-default block inside an editor: a header (caret, title,
// hint) that folds its content. Children go into the body.
StyledRect {
    id: root

    property string title: ""
    property string hint: ""
    property bool expanded: false
    default property alias content: body.data

    variant: "common"
    radius: Look.radius("control")
    implicitHeight: col.implicitHeight + 20

    ColumnLayout {
        id: col
        x: 10
        y: 10
        width: parent.width - 20
        spacing: Space.m

        Item {
            objectName: "surfacesMore"
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: root.title
            Keys.onReturnPressed: root.expanded = !root.expanded
            Keys.onSpacePressed: root.expanded = !root.expanded

            RowLayout {
                id: header
                width: parent.width
                spacing: Space.s

                Icon {
                    icon: root.expanded ? Icons.caretDown : Icons.caretRight
                    color: root.item
                }
                KitText {
                    role: "secondary"
                    text: root.title
                    font.bold: true
                    color: root.item
                }
                KitText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: root.hint
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    color: Colors.overSurfaceVariant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            visible: root.expanded
            spacing: Space.m
        }
    }
}
