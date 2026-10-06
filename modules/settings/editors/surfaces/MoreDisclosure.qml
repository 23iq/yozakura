import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Collapsed-by-default block inside an editor: a header (caret, title,
// hint) that folds its content. Children go into the body.
StyledRect {
    id: root

    property string title: ""
    property string hint: ""
    property bool expanded: false
    default property alias content: body.data

    variant: "common"
    radius: Styling.radius(-1)
    implicitHeight: col.implicitHeight + 20

    ColumnLayout {
        id: col
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 12

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
                spacing: 8

                Text {
                    text: root.expanded ? Icons.caretDown : Icons.caretRight
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: root.item
                }
                Text {
                    text: root.title
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.bold: true
                    color: root.item
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hint
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
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
            spacing: 12
        }
    }
}
