pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.aicenter.common

// A small popup list: options [{value, label, detail}], the current value
// is marked; picking closes the menu.
Popup {
    id: root

    property var options: []
    property string current: ""
    signal picked(string value)

    padding: Space.s
    width: 260
    background: StyledRect {
        variant: "popup"
        radius: Look.radius("control")
        enableShadow: true
    }
    contentItem: ColumnLayout {
        spacing: Space.xs / 2
        Repeater {
            model: root.options
            delegate: StyledRect {
                id: item
                required property var modelData
                objectName: "option_" + item.modelData.value
                Layout.fillWidth: true
                implicitHeight: itemCol.implicitHeight + 2 * Space.xs
                radius: Look.radius("small")
                variant: hover.hovered ? "common" : (root.current === item.modelData.value ? "focus" : "transparent")
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        root.close();
                        root.picked(item.modelData.value);
                    }
                }
                ColumnLayout {
                    id: itemCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Space.s
                    anchors.rightMargin: Space.s
                    spacing: 0
                    AiText {
                        role: "caption"
                        color: Type.text
                        Layout.fillWidth: true
                        text: item.modelData.label
                        mono: item.modelData.mono === true
                    }
                    AiText {
                        role: "caption"
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: item.modelData.detail || ""
                    }
                }
            }
        }
    }
}
