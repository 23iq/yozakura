import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The cheatsheet's heading is its search field: a title-role input whose
// placeholder is the title ("Keyboard shortcuts"), so typing turns the
// heading into the query. Up/Down/Return/Escape are forwarded as signals.
Item {
    id: root

    property alias text: input.text
    property string placeholderText: ""

    signal searchTextChanged(string text)
    signal accepted
    signal escapePressed
    signal upPressed
    signal downPressed

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitWidth: glyph.implicitWidth + Space.m + Math.max(input.contentWidth, placeholder.implicitWidth)
    implicitHeight: Math.max(Space.controlM, placeholder.implicitHeight)

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.search
        font.family: Icons.font
        font.pixelSize: Type.iconSize("title")
        color: input.activeFocus || input.text !== "" ? Type.text : Type.muted
    }

    KitText {
        id: placeholder
        anchors.left: input.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        role: "title"
        visible: input.text === ""
        text: root.placeholderText
    }

    TextInput {
        id: input
        objectName: "cheatsheetSearchInput"
        anchors.left: glyph.right
        anchors.leftMargin: Space.m
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        font.family: Type.family("title")
        font.pixelSize: Type.size("title")
        font.weight: Type.weight("title")
        color: Type.text
        selectionColor: Type.accent
        selectedTextColor: Type.onAccent
        cursorDelegate: Rectangle {
            width: Space.hairline * 2
            color: Type.accent
            visible: parent ? parent.activeFocus : false
        }
        clip: true
        onTextChanged: root.searchTextChanged(text)
        onAccepted: root.accepted()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.escapePressed();
            else if (event.key === Qt.Key_Down)
                root.downPressed();
            else if (event.key === Qt.Key_Up)
                root.upPressed();
            else
                return;
            event.accepted = true;
        }
    }
}
