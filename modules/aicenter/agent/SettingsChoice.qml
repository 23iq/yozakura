pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.config

ComboBox {
    id: root
    textRole: "name"
    valueRole: "id"
    implicitHeight: Space.controlS
    leftPadding: Space.s
    rightPadding: Space.xxl
    opacity: enabled ? 1 : 0.55
    contentItem: KitText {
        role: "secondary"
        text: root.displayText
        color: Type.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: StyledRect {
        variant: "common"
        radius: Look.radius("control")
        border.width: root.activeFocus ? 1 : 0
        border.color: Colors.primary
    }
    indicator: Icon {
        role: "label"
        tone: "muted"
        anchors.right: parent.right
        anchors.rightMargin: Space.s
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.caretUpDown
    }
    delegate: ItemDelegate {
        id: entry
        required property int index
        required property var modelData
        width: root.width
        highlighted: root.highlightedIndex === index
        contentItem: KitText {
            role: "secondary"
            text: entry.modelData.name
            color: Type.text
        }
        background: StyledRect {
            variant: entry.highlighted ? "focus" : "transparent"
            radius: Look.radius("control")
        }
    }
    popup: Popup {
        y: root.height + Space.xs
        width: root.width
        padding: Space.s
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
            radius: Look.radius("control")
        }
    }
}
