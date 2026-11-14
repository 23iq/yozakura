import QtQuick
import QtQuick.Effects
import qs.config
import qs.modules.components.kit

// Text field in a FieldBox. `edited(text)` on Enter / focus loss. `multiline`
// (long prose such as a system prompt): a wrapping box of a few lines that
// commits on focus loss or Ctrl+Enter, the whole text visible instead of a
// single line scrolled to its end.
Item {
    id: root

    property string text: ""
    property string placeholder: ""
    property bool monospace: false
    // A credential: shown as dots unless the field has the focus
    property bool secret: false
    property bool invalid: false
    property bool multiline: false
    // the lines a multiline box shows before it scrolls
    property int lines: 5
    property alias input: field
    signal edited(string text)

    implicitWidth: 280
    implicitHeight: root.multiline ? Math.round(Type.size("secondary") * 1.45 * root.lines + Space.m * 2) : box.implicitHeight

    onTextChanged: {
        if (!field.activeFocus)
            field.text = text;
        if (!area.activeFocus)
            area.text = text;
    }

    FieldBox {
        id: box
        anchors.fill: parent
        hovered: hover.hovered
        focused: field.activeFocus || area.activeFocus
        invalid: root.invalid
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.IBeamCursor
    }

    Flickable {
        id: areaFlick
        visible: root.multiline
        anchors.fill: parent
        anchors.margins: Space.m
        contentWidth: width
        contentHeight: area.contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        // more text above / below the box: it fades out at the cut
        readonly property bool moreAbove: areaFlick.contentY > 1
        readonly property bool moreBelow: areaFlick.contentY < areaFlick.contentHeight - areaFlick.height - 1
        layer.enabled: root.multiline && (areaFlick.moreAbove || areaFlick.moreBelow)
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        TextEdit {
            id: area
            objectName: "textArea"
            width: areaFlick.width
            text: root.text
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            font.family: root.monospace ? Config.theme.monoFont : Type.bodyFont
            font.pixelSize: Type.size("secondary")
            color: Type.text
            selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
            selectedTextColor: Type.text
            Accessible.role: Accessible.EditableText
            onActiveFocusChanged: if (!activeFocus && text !== root.text)
                root.edited(text)
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                    area.focus = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    area.text = root.text;
                    area.focus = false;
                    event.accepted = true;
                }
            }
            onCursorRectangleChanged: {
                const r = area.cursorRectangle;
                if (r.y < areaFlick.contentY)
                    areaFlick.contentY = r.y;
                else if (r.y + r.height > areaFlick.contentY + areaFlick.height)
                    areaFlick.contentY = r.y + r.height - areaFlick.height;
            }
        }
        KitText {
            width: parent.width
            role: "secondary"
            text: root.placeholder
            color: Type.muted
            wrapMode: Text.WordWrap
            visible: area.text === "" && !area.activeFocus
        }
    }
    // the mask of the fades: opaque, transparent over the last line or so
    // on the side that has more
    Item {
        id: fadeMask
        visible: false
        width: areaFlick.width
        height: areaFlick.height
        layer.enabled: root.multiline
        readonly property real band: Math.min(0.45, Space.xl / Math.max(1, height))
        Mark {
            anchors.fill: parent
            radius: 0
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: areaFlick.moreAbove ? "transparent" : "black"
                }
                GradientStop {
                    position: fadeMask.band
                    color: "black"
                }
                GradientStop {
                    position: 1 - fadeMask.band
                    color: "black"
                }
                GradientStop {
                    position: 1
                    color: areaFlick.moreBelow ? "transparent" : "black"
                }
            }
        }
    }

    TextInput {
        id: field
        visible: !root.multiline
        anchors.fill: parent
        anchors.leftMargin: Space.m
        anchors.rightMargin: Space.m
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        clip: true
        selectByMouse: true
        echoMode: root.secret && !field.activeFocus ? TextInput.Password : TextInput.Normal
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
