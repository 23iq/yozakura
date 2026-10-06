import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.signatures
import "Ui.js" as Ui

// One sidebar category: icon tile + label, with a selection pill.
Item {
    id: item

    required property var category
    property bool selected: false
    property bool compact: false
    signal clicked

    height: 40
    objectName: "nav:" + category.id
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()

    Accessible.role: Accessible.PageTab
    Accessible.name: I18n.t(category.title)

    BrushHighlight {
        shown: item.selected
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(0), 14)
        color: item.selected ? Ui.alpha(Colors.primary, 0.15) : (area.containsMouse ? Ui.alpha(Colors.overBackground, 0.1) : "transparent")
        border.width: item.activeFocus ? 2 : 0
        border.color: Colors.primary
        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
            }
        }
    }

    // Accent bar
    Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: item.selected ? 18 : 0
        radius: 2
        color: Colors.primary
        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        id: icon
        x: item.compact ? (parent.width - width) / 2 : 14
        anchors.verticalCenter: parent.verticalCenter
        text: Icons[item.category.icon] ?? ""
        font.family: Icons.font
        font.pixelSize: 18
        color: item.selected ? Colors.primary : Colors.overSurfaceVariant
    }

    Text {
        visible: !item.compact
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t(item.category.title)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: item.selected ? Font.Bold : Font.Medium
        color: item.selected ? Colors.overBackground : Ui.alpha(Colors.overBackground, 0.86)
        elide: Text.ElideRight
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
}
