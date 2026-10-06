pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.config

ComboBox {
    id: root
    textRole: "name"
    valueRole: "id"
    implicitHeight: 36
    leftPadding: 10
    rightPadding: 30
    opacity: enabled ? 1 : 0.55
    contentItem: Text {
        text: root.displayText
        color: Colors.overSurface
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: StyledRect {
        variant: "common"
        radius: Styling.radius(-4)
        border.width: root.activeFocus ? 1 : 0
        border.color: Colors.primary
    }
    indicator: Text {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.caretUpDown
        font.family: Icons.font
        font.pixelSize: 12
        color: Colors.outline
    }
    delegate: ItemDelegate {
        id: entry
        required property int index
        required property var modelData
        width: root.width
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: entry.modelData.name
            color: Colors.overSurface
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
        }
        background: StyledRect {
            variant: entry.highlighted ? "focus" : "transparent"
            radius: Styling.radius(-4)
        }
    }
    popup: Popup {
        y: root.height + 4
        width: root.width
        padding: 6
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollBar.vertical: ScrollBar {}
        }
        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(-4)
        }
    }
}
