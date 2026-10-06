pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.aicenter.common

// A small popup list: options [{value, label, detail}], the current value
// is marked; picking closes the menu.
Popup {
    id: root

    property var options: []
    property string current: ""
    signal picked(string value)

    padding: 6
    width: 260
    background: StyledRect {
        variant: "popup"
        radius: Styling.radius(-2)
        enableShadow: true
    }
    contentItem: ColumnLayout {
        spacing: 2
        Repeater {
            model: root.options
            delegate: StyledRect {
                id: item
                required property var modelData
                objectName: "option_" + item.modelData.value
                Layout.fillWidth: true
                implicitHeight: itemCol.implicitHeight + 10
                radius: Styling.radius(-6)
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
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 0
                    UiText {
                        Layout.fillWidth: true
                        text: item.modelData.label
                        size: -2
                        mono: item.modelData.mono === true
                    }
                    UiText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: item.modelData.detail || ""
                        muted: true
                        size: -4
                    }
                }
            }
        }
    }
}
