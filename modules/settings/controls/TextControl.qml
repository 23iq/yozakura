import QtQuick
import qs.modules.theme
import qs.config
import "../Ui.js" as Ui

// Single-line text field. `edited(text)` on Enter / focus loss.
Item {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool monospace: false
    property bool invalid: false
    property alias input: field
    signal edited(string text)

    implicitWidth: 280
    implicitHeight: 36

    onTextChanged: if (!field.activeFocus)
        field.text = text

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(0), height / 2)
        color: Ui.alpha(Colors.overBackground, 0.06)
        border.width: field.activeFocus || root.invalid ? 2 : 1
        border.color: root.invalid ? Colors.error : (field.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.35))
    }

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        clip: true
        selectByMouse: true
        font.family: root.monospace ? Config.theme.monoFont : Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        color: Colors.overBackground
        selectionColor: Ui.alpha(Colors.primary, 0.4)
        selectedTextColor: Colors.overBackground
        onEditingFinished: if (text !== root.text)
            root.edited(text)
        Keys.onEscapePressed: {
            text = root.text;
            focus = false;
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            font: field.font
            color: Ui.alpha(Colors.overSurfaceVariant, 0.6)
            visible: field.text === "" && !field.activeFocus
            elide: Text.ElideRight
        }
    }
}
