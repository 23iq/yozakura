pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Labelled text field of the Connect sheet. `secret` hides the text (API
// keys) with a show/hide toggle; every field has a paste button.
ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property string placeholder: ""
    property bool secret: false
    property bool mono: false
    property bool revealed: false
    property alias text: field.text
    property alias field: field

    signal edited

    spacing: 6

    function focusField() {
        field.forceActiveFocus();
    }

    Text {
        visible: root.label.length > 0
        text: root.label
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-1)
        font.weight: Font.Medium
        color: Colors.overSurface
    }
    StyledRect {
        Layout.fillWidth: true
        implicitHeight: Math.max(field.implicitHeight, 36) + 4
        variant: field.activeFocus ? "focus" : "pane"
        radius: Styling.radius(-4)
        enableBorder: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 2
            TextField {
                id: field
                objectName: root.objectName ? root.objectName + "Input" : ""
                Layout.fillWidth: true
                placeholderText: root.placeholder
                echoMode: root.secret && !root.revealed ? TextInput.Password : TextInput.Normal
                selectByMouse: true
                color: Colors.overSurface
                placeholderTextColor: Colors.outline
                selectionColor: Colors.primary
                selectedTextColor: Colors.overPrimary
                font.family: root.mono || (root.secret && root.revealed) ? Config.theme.monoFont : Config.theme.font
                font.pixelSize: BarLook.font(-1)
                background: null
                leftPadding: 0
                rightPadding: 0
                onTextEdited: root.edited()
            }
            IconButton {
                objectName: root.objectName ? root.objectName + "Paste" : ""
                glyph: Icons.clipboardText
                size: 28
                iconSize: 14
                tooltip: I18n.t("ai.connect.paste")
                onClicked: {
                    field.selectAll();
                    field.paste();
                    root.edited();
                }
            }
            IconButton {
                objectName: root.objectName ? root.objectName + "Reveal" : ""
                visible: root.secret
                glyph: Icons.eye
                size: 28
                iconSize: 14
                active: root.revealed
                tooltip: root.revealed ? I18n.t("ai.connect.hide") : I18n.t("ai.connect.show")
                onClicked: root.revealed = !root.revealed
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.hint.length > 0
        text: root.hint
        wrapMode: Text.Wrap
        font.family: Config.theme.font
        font.pixelSize: BarLook.font(-3)
        color: Colors.outline
    }
}
