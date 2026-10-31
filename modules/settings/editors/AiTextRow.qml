pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.components.kit
import qs.modules.settings.controls

// Label + text field (kit FieldBox look); `edited(text)` fires when editing
// finishes.
ColumnLayout {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property bool mono: false
    property bool multiline: false
    signal edited(string text)

    Layout.fillWidth: true
    spacing: Space.xs

    readonly property string currentText: root.multiline ? area.text : line.input.text

    function commit(text) {
        if (text !== root.value)
            root.edited(text);
    }

    // Saved when the page goes away too, so a window closed with the focus
    // still in the field keeps the value.
    Component.onDestruction: root.commit(root.currentText)

    KitText {
        visible: root.label.length > 0
        role: "secondary"
        text: root.label
    }

    TextControl {
        id: line
        visible: !root.multiline
        Layout.fillWidth: true
        text: root.value
        placeholder: root.placeholder
        monospace: root.mono
        onEdited: t => root.commit(t)
    }

    FieldBox {
        id: box
        visible: root.multiline
        Layout.fillWidth: true
        implicitHeight: Math.min(Math.max(area.contentHeight, 60), 180) + 2 * Space.s
        focused: area.activeFocus
        hovered: areaHover.hovered

        HoverHandler {
            id: areaHover
            cursorShape: Qt.IBeamCursor
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: Space.s
            contentWidth: width
            contentHeight: area.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: area
                width: scroller.width
                text: root.value
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                font.family: root.mono ? Config.theme.monoFont : Type.bodyFont
                font.pixelSize: Type.size("secondary")
                color: Type.text
                selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
                selectedTextColor: Type.text
                onActiveFocusChanged: if (!activeFocus)
                    root.commit(text)
                onCursorRectangleChanged: {
                    if (cursorRectangle.y < scroller.contentY)
                        scroller.contentY = cursorRectangle.y;
                    else if (cursorRectangle.y + cursorRectangle.height > scroller.contentY + scroller.height)
                        scroller.contentY = cursorRectangle.y + cursorRectangle.height - scroller.height;
                }

                KitText {
                    role: "secondary"
                    text: root.placeholder
                    color: Type.muted
                    visible: area.text === "" && !area.activeFocus
                }
            }
        }
    }
}
