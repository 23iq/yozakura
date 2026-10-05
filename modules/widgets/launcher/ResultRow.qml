pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
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

    implicitHeight: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 10
        spacing: 12

        // Icon tile
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            // App icon from the icon theme
            Image {
                id: themeIcon
                anchors.fill: parent
                visible: !!row.item.image && !row.item.thumb
                // Theme icon name, or an absolute path (Icon=/path in .desktop)
                source: !visible ? "" : row.item.image.charAt(0) === "/" ? "file://" + row.item.image : "image://icon/" + row.item.image
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                mipmap: true
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Error)
                        source = "image://icon/image-missing";
                }
            }
            Tinted {
                anchors.fill: parent
                visible: themeIcon.visible
                sourceItem: themeIcon
            }

            // Wallpaper / file thumbnail
            ClippingRectangle {
                anchors.fill: parent
                visible: !!row.item.thumb
                radius: Styling.radius(-6)
                color: Colors.surfaceContainerHigh
                Image {
                    anchors.fill: parent
                    source: parent.visible ? row.item.image : ""
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Glyph
            StyledRect {
                anchors.fill: parent
                visible: !row.item.image
                variant: row.selected ? "overprimary" : "common"
                radius: Styling.radius(-6)
                Text {
                    anchors.centerIn: parent
                    text: row.item.icon || ""
                    font.family: Icons.font
                    font.pixelSize: 17
                    color: row.selected ? Styling.srItem("overprimary") : row.inert ? Colors.outline : Colors.primary
                }
            }
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
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutCubic
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
            Layout.preferredHeight: 22
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
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
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
