pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Card look of a launcher result (layout.launcher.resultStyle = "cards"):
// a larger icon, the title, a subtitle and a badge row; when selected the
// Enter hint replaces the badge. Same contract as ResultRow.
Item {
    id: card

    required property var item
    property bool selected: false
    property bool expanded: false
    readonly property bool emphasis: !!item.emphasis
    readonly property bool inert: !!item.inert
    readonly property color fg: expanded ? Styling.srItem("pane") : selected ? Styling.srItem("primary") : Colors.overBackground
    readonly property color dim: expanded ? Styling.srItem("pane") : selected ? Styling.srItem("primary") : Colors.outline

    implicitHeight: Math.round(Metrics.rowHeight * 1.5)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacing + 2
        anchors.rightMargin: Metrics.spacing + 4
        spacing: Metrics.spacing + 6

        ResultIcon {
            Layout.preferredWidth: Math.round(Metrics.iconSize * 1.375)
            Layout.preferredHeight: Math.round(Metrics.iconSize * 1.375)
            Layout.alignment: Qt.AlignVCenter
            item: card.item
            selected: card.selected
            size: Math.round(Metrics.iconSize * 1.375)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: card.item.title || ""
                color: card.inert && !card.selected ? Colors.outline : card.fg
                font.family: card.emphasis ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: card.emphasis ? Styling.fontSize(3) : Styling.fontSize(1)
                font.weight: card.inert ? Font.Medium : Font.Bold
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
                Layout.fillWidth: true
                visible: text !== ""
                text: card.item.subtitle || ""
                color: card.dim
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }

            // Badge row: provider badge, or the Enter hint when selected
            Item {
                Layout.preferredHeight: Metrics.badgeHeight
                Layout.fillWidth: true
                visible: !card.inert && (badge.text !== "" || hint.text !== "")

                StyledRect {
                    id: pill
                    anchors.verticalCenter: parent.verticalCenter
                    width: badge.implicitWidth + Metrics.spacing * 2
                    height: Metrics.badgeHeight - 4
                    variant: card.selected ? "overprimary" : "common"
                    radius: height / 2
                    opacity: card.selected ? 0 : 1
                    visible: badge.text !== ""
                    Behavior on opacity {
                        enabled: Motion.enter.duration > 0
                        NumberAnimation {
                            duration: Motion.enter.duration / 2
                            easing.type: Motion.enter.easing
                        }
                    }
                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: card.item.badge || ""
                        color: Colors.outline
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        font.weight: Font.Medium
                        font.letterSpacing: 0.4
                    }
                }

                KeyHint {
                    id: hint
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.item.hint || ""
                    color: Styling.srItem("primary")
                    opacity: card.selected && !card.expanded ? 1 : 0
                    Behavior on opacity {
                        enabled: Motion.enter.duration > 0
                        NumberAnimation {
                            duration: Motion.enter.duration / 2
                            easing.type: Motion.enter.easing
                        }
                    }
                }
            }
        }
    }
}
