import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Right side of the notes tab: the editor of the open note (rich text or
// markdown), a hint when none is open, a spinner while it loads and the
// save-failure notice under the editor.
Item {
    id: pane

    // The NotesTab (open note state + noteEdited / focusSearchInput)
    required property var tab

    function focusEditor(markdown) {
        if (markdown)
            markdownEditor.focusEditor();
        else
            richEditor.focusEditor();
    }

    function text(markdown) {
        return markdown ? markdownEditor.text : richEditor.text;
    }

    function setText(markdown, value) {
        if (markdown)
            markdownEditor.setText(value);
        else
            richEditor.setText(value);
    }

    RichTextEditor {
        id: richEditor
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: saveNotice.visible ? saveNotice.top : parent.bottom
        visible: pane.tab.currentNoteId !== "" && !pane.tab.currentNoteIsMarkdown
        content: pane.tab.currentNoteContent
        onEdited: pane.tab.noteEdited(false)
        onEscapePressed: pane.tab.focusSearchInput()
    }

    MarkdownEditor {
        id: markdownEditor
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: saveNotice.visible ? saveNotice.top : parent.bottom
        visible: pane.tab.currentNoteId !== "" && pane.tab.currentNoteIsMarkdown
        content: pane.tab.currentNoteContent
        onEdited: pane.tab.noteEdited(true)
        onEscapePressed: pane.tab.focusSearchInput()
    }

    // The open note could not be saved: retry or discard (NotesTab)
    NoteSaveNotice {
        id: saveNotice
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: pane.tab.currentNoteId !== "" && pane.tab.saveFailed
        onRetry: pane.tab.retrySave()
        onDiscard: pane.tab.discardChanges()
    }

    KitText {
        anchors.centerIn: parent
        visible: pane.tab.currentNoteId === ""
        role: "secondary"
        color: Type.muted
        text: I18n.t("notes.select_or_create")
    }

    Text {
        anchors.centerIn: parent
        visible: pane.tab.loadingNote
        text: Icons.spinnerGap
        font.family: Icons.font
        font.pixelSize: Type.iconSize("title")
        color: Type.secondary

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            running: pane.tab.loadingNote
        }
    }
}
