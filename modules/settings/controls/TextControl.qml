import QtQuick
import qs.config
import qs.modules.components.kit

// Single-line text field in a FieldBox. `edited(text)` on Enter / focus loss.
Item {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool monospace: false
    property bool invalid: false
    property alias input: field
    signal edited(string text)

    implicitWidth: 280
    implicitHeight: box.implicitHeight

    onTextChanged: if (!field.activeFocus)
        field.text = text

    FieldBox {
        id: box
        anchors.fill: parent
        hovered: hover.hovered
        focused: field.activeFocus
        invalid: root.invalid
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.IBeamCursor
    }

    TextInput {
        id: field
        anchors.fill: parent
        anchors.leftMargin: Space.m
        anchors.rightMargin: Space.m
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        clip: true
        selectByMouse: true
        font.family: root.monospace ? Config.theme.monoFont : Type.bodyFont
        font.pixelSize: Type.size("secondary")
        color: Type.text
        selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
        selectedTextColor: Type.text
        onEditingFinished: if (text !== root.text)
            root.edited(text)
        Keys.onEscapePressed: {
            text = root.text;
            focus = false;
        }

        KitText {
            anchors.fill: parent
            role: "secondary"
            text: root.placeholder
            font.family: field.font.family
            color: Type.muted
            visible: field.text === "" && !field.activeFocus
        }
    }
}
