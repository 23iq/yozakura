pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// One launcher result: icon tile (app icon, thumbnail or glyph), title and
// subtitle, and on the right the provider badge or, when selected, what
// Enter does. Colors follow the selection highlight drawn by ResultList.
Item {
    id: row

    required property var item
    property bool selected: false
    property bool expanded: false
    readonly property bool emphasis: !!item.emphasis
    readonly property bool inert: !!item.inert
    readonly property color fg: expanded ? Styling.srItem("pane") : selected ? Styling.srItem("primary") : Colors.overBackground
    readonly property color dim: expanded ? Styling.srItem("pane") : selected ? Styling.srItem("primary") : Colors.outline

    implicitHeight: Metrics.rowHeight

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 10
        spacing: 12

        ResultIcon {
            Layout.preferredWidth: Metrics.iconSize
            Layout.preferredHeight: Metrics.iconSize
            item: row.item
            selected: row.selected
        }

        // Title + subtitle
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: row.emphasis ? -1 : 0

            Text {
                width: parent.width
                text: row.item.title || ""
                color: row.inert && !row.selected ? Colors.outline : row.fg
                font.family: row.emphasis ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: row.emphasis ? Styling.fontSize(3) : Config.theme.fontSize
                font.weight: row.inert ? Font.Medium : Font.Bold
                elide: Text.ElideRight
                maximumLineCount: 1
                Behavior on color {
                    enabled: Motion.enter.duration > 0
                    ColorAnimation {
                        duration: Motion.enter.duration / 2
                        easing.type: Motion.enter.easing
                    }
                }
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.item.subtitle || ""
                color: row.dim
                opacity: row.selected ? 0.85 : 1
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }

        // Right side: provider badge, or the Enter hint on the selected row
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(badge.implicitWidth, hint.implicitWidth)
            Layout.preferredHeight: Metrics.badgeHeight
            visible: !row.inert && (badge.text !== "" || hint.text !== "")

            Text {
                id: badge
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.item.badge || ""
                opacity: row.selected ? 0 : 0.9
                color: Colors.outline
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Medium
                font.letterSpacing: 0.4
                Behavior on opacity {
                    enabled: Motion.enter.duration > 0
                    NumberAnimation {
                        duration: Motion.enter.duration / 2
                        easing.type: Motion.enter.easing
                    }
                }
            }

            KeyHint {
                id: hint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: row.item.hint || ""
                color: Styling.srItem("primary")
                opacity: row.selected && !row.expanded ? 1 : 0
            }
        }
    }
}
