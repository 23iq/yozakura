pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Label + text field; `edited(text)` fires when editing finishes.
ColumnLayout {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property bool mono: false
    property bool multiline: false
    signal edited(string text)

    Layout.fillWidth: true
    spacing: 4

    readonly property string currentText: root.multiline ? area.text : field.text

    function commit(text) {
        if (text !== root.value)
            root.edited(text);
    }

    // Saved when the page goes away too, so a window closed with the focus
    // still in the field keeps the value.
    Component.onDestruction: root.commit(root.currentText)

    Text {
        visible: root.label.length > 0
        text: root.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.Medium
        color: Colors.overSurfaceVariant
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: root.multiline ? Math.min(Math.max(area.implicitHeight, 60), 180) + 12 : 34
        variant: "internalbg"
        radius: Styling.radius(-4)
        border.width: field.activeFocus || area.activeFocus ? 1 : 0
        border.color: Colors.primary

        TextField {
            id: field
            visible: !root.multiline
            anchors.fill: parent
            text: root.value
            placeholderText: root.placeholder
            placeholderTextColor: Colors.outline
            color: Colors.overSurface
            font.family: root.mono ? Config.theme.monoFont : Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            background: null
            onEditingFinished: root.commit(text)
        }
        ScrollView {
            visible: root.multiline
            anchors.fill: parent
            anchors.margins: 6
            TextArea {
                id: area
                text: root.value
                placeholderText: root.placeholder
                placeholderTextColor: Colors.outline
                color: Colors.overSurface
                wrapMode: TextArea.Wrap
                font.family: root.mono ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                background: null
                onActiveFocusChanged: if (!activeFocus)
                    root.commit(text)
            }
        }
    }
}
