import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.desktop.widgets

// Sticky note: free text kept in the widget's options (desktop.json, so it
// travels with presets), saved a moment after typing stops.
DesktopWidget {
    id: root

    readonly property string tintRole: options.tint ?? "tertiary"
    readonly property color tint: tintRole !== "none" && Colors[tintRole] !== undefined ? Colors[tintRole] : "transparent"
    readonly property string saved: options.text ?? ""

    // Follow the stored text unless the user is typing (a save reloads
    // desktop.json and must not move the cursor).
    onSavedChanged: {
        if (!editor.activeFocus && editor.text !== saved)
            editor.text = saved;
    }

    Rectangle {
        anchors.fill: parent
        color: root.tint
        opacity: 0.16
        visible: root.tintRole !== "none"
    }

    Rectangle {
        x: root.pad
        y: Math.round(root.pad * 0.6)
        width: Math.round(36 * root.k)
        height: Math.max(3, Math.round(4 * root.k))
        radius: height / 2
        color: root.tintRole !== "none" ? root.tint : root.inkSoft
    }

    Flickable {
        id: flick
        x: root.pad
        y: Math.round(root.pad * 1.3)
        width: root.width - 2 * root.pad
        height: root.height - y - root.pad
        contentWidth: width
        contentHeight: editor.contentHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: editor
            width: flick.width
            text: root.saved
            wrapMode: TextEdit.Wrap
            readOnly: root.editing || root.preview
            selectByMouse: true
            font.family: root.font
            font.pixelSize: root.px(0)
            color: root.ink
            selectionColor: Colors.primary
            selectedTextColor: Colors.overPrimary
            onTextChanged: {
                if (activeFocus)
                    saveTimer.restart();
            }
            onActiveFocusChanged: {
                if (!activeFocus && saveTimer.running) {
                    saveTimer.stop();
                    root.optionChanged("text", text);
                }
            }
            onCursorRectangleChanged: {
                if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
                else if (cursorRectangle.y < flick.contentY)
                    flick.contentY = cursorRectangle.y;
            }

            Text {
                visible: editor.text === ""
                width: parent.width
                text: I18n.t("desktop.widgets.note.placeholder")
                wrapMode: Text.WordWrap
                font: editor.font
                color: root.inkSoft
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 900
        onTriggered: root.optionChanged("text", editor.text)
    }
}
