import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// WYSIWYG editor of rich text (.html) notes: formatting toolbar (font size,
// bold/italic/underline/strikeout, alignment) and the TextArea with its
// shortcuts (Ctrl+B/I/U/D, Alt+Up/Down size, Alt+Left/Right alignment).
ColumnLayout {
    id: pane

    property string content: ""
    readonly property alias text: noteEditor.text

    // Emitted on every text change (the tab decides whether it is an edit)
    signal edited
    signal escapePressed

    function focusEditor() {
        noteEditor.forceActiveFocus();
    }

    spacing: 8

    RichTextFormat {
        id: format
        editor: noteEditor
    }

    // Formatting toolbar
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 40

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4

            // Font size controls: minus button, input, plus button
            NoteToolButton {
                glyph: Icons.minus
                tooltip: "Decrease font size (Alt+Down)"
                onClicked: format.stepFontSize(false)
            }

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 32
                radius: Styling.radius(-4)
                color: "transparent"

                StyledRect {
                    anchors.fill: parent
                    variant: fontSizeField.activeFocus ? "primary" : "surface"
                    radius: Styling.radius(-4)
                }

                TextInput {
                    id: fontSizeField
                    anchors.centerIn: parent
                    width: parent.width - 8
                    horizontalAlignment: TextInput.AlignHCenter
                    text: format.getCurrentFontSize().toString()
                    font.family: Config.theme.font
                    font.pixelSize: 14
                    color: fontSizeField.activeFocus ? Colors.overPrimary : Colors.overSurface
                    selectByMouse: true
                    validator: IntValidator {
                        bottom: 8
                        top: 200
                    }

                    onEditingFinished: {
                        let size = parseInt(fontSizeField.text);
                        if (!isNaN(size) && size >= 8 && size <= 200) {
                            format.setFontSize(size);
                        } else {
                            fontSizeField.text = format.getCurrentFontSize().toString();
                        }
                        noteEditor.forceActiveFocus();
                    }

                    Keys.onEscapePressed: {
                        fontSizeField.text = format.getCurrentFontSize().toString();
                        noteEditor.forceActiveFocus();
                    }
                }
            }

            NoteToolButton {
                glyph: Icons.plus
                tooltip: "Increase font size (Alt+Up)"
                onClicked: format.stepFontSize(true)
            }

            ToolbarDivider {}

            NoteToolButton {
                glyph: "B"
                glyphFont: Config.theme.font
                glyphBold: true
                active: format.isBold()
                tooltip: "Bold (Ctrl+B)"
                onClicked: format.toggleBold()
            }

            NoteToolButton {
                glyph: "I"
                glyphFont: Config.theme.font
                glyphItalic: true
                active: format.isItalic()
                tooltip: "Italic (Ctrl+I)"
                onClicked: format.toggleItalic()
            }

            NoteToolButton {
                glyph: "U"
                glyphFont: Config.theme.font
                glyphUnderline: true
                active: format.isUnderline()
                tooltip: "Underline (Ctrl+U)"
                onClicked: format.toggleUnderline()
            }

            NoteToolButton {
                glyph: "S"
                glyphFont: Config.theme.font
                glyphStrikeout: true
                active: format.isStrikeout()
                tooltip: "Strikethrough (Ctrl+D)"
                onClicked: format.toggleStrikeout()
            }

            ToolbarDivider {}

            NoteToolButton {
                glyph: Icons.alignLeft
                active: noteEditor.cursorSelection.alignment === Qt.AlignLeft
                tooltip: "Align Left (Alt+Left)"
                onClicked: format.setAlignment(Qt.AlignLeft)
            }

            NoteToolButton {
                glyph: Icons.alignCenter
                active: noteEditor.cursorSelection.alignment === Qt.AlignHCenter
                tooltip: "Align Center (Alt+Left/Right)"
                onClicked: format.setAlignment(Qt.AlignHCenter)
            }

            NoteToolButton {
                glyph: Icons.alignRight
                active: noteEditor.cursorSelection.alignment === Qt.AlignRight
                tooltip: "Align Right (Alt+Left/Right)"
                onClicked: format.setAlignment(Qt.AlignRight)
            }

            NoteToolButton {
                glyph: Icons.alignJustify
                active: noteEditor.cursorSelection.alignment === Qt.AlignJustify
                tooltip: "Justify (Alt+Right)"
                onClicked: format.setAlignment(Qt.AlignJustify)
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // Separator below toolbar
    Separator {
        Layout.fillWidth: true
        Layout.preferredHeight: 2
    }

    // WYSIWYG Editor
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Flickable {
            id: editorFlickable
            anchors.fill: parent
            contentWidth: width
            contentHeight: noteEditor.contentHeight + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextArea.flickable: TextArea {
                id: noteEditor
                text: pane.content
                textFormat: TextEdit.RichText
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.overSurface
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                persistentSelection: true
                placeholderText: I18n.t("notes.start_typing")
                leftPadding: 8
                rightPadding: 8
                topPadding: 8
                bottomPadding: 8
                background: Item {}

                onTextChanged: pane.edited()

                // Track if cursor moved due to typing or user navigation
                property int lastCursorPos: 0
                property bool cursorMovedByTyping: false

                // Reset pre-format when cursor moves by navigation (not typing)
                onCursorPositionChanged: {
                    if (noteEditor.applyingFormat)
                        return;

                    // If length changed, cursor moved due to typing - don't reset
                    if (noteEditor.cursorMovedByTyping) {
                        noteEditor.cursorMovedByTyping = false;
                        noteEditor.lastCursorPos = noteEditor.cursorPosition;
                        return;
                    }

                    // Cursor moved by more than 1 position or moved backward = navigation
                    let delta = noteEditor.cursorPosition - noteEditor.lastCursorPos;
                    if (delta < 0 || delta > 1) {
                        format.resetPreFormat();
                    }
                    noteEditor.lastCursorPos = noteEditor.cursorPosition;
                }

                Keys.onEscapePressed: pane.escapePressed()

                // Formatting shortcuts
                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) {
                        switch (event.key) {
                        case Qt.Key_B:
                            format.toggleBold();
                            event.accepted = true;
                            break;
                        case Qt.Key_I:
                            format.toggleItalic();
                            event.accepted = true;
                            break;
                        case Qt.Key_U:
                            format.toggleUnderline();
                            event.accepted = true;
                            break;
                        case Qt.Key_D:
                            format.toggleStrikeout();
                            event.accepted = true;
                            break;
                        }
                    }
                    // Alt+Up/Down to increase/decrease font size
                    // Alt+Left/Right to cycle through alignments
                    if (event.modifiers & Qt.AltModifier) {
                        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                            format.stepFontSize(event.key === Qt.Key_Up);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            format.stepAlignment(event.key === Qt.Key_Right);
                            event.accepted = true;
                        }
                    }
                }

                // Apply pre-format when inserting text
                property int lastLength: 0
                property bool applyingFormat: false
                onLengthChanged: {
                    // Prevent recursion
                    if (noteEditor.applyingFormat)
                        return;

                    // Mark that cursor will move due to typing
                    if (noteEditor.length !== noteEditor.lastLength) {
                        noteEditor.cursorMovedByTyping = true;
                    }

                    // Detect if text was inserted (not deleted)
                    if (noteEditor.length > noteEditor.lastLength && !format.hasSelection() && format.hasActivePreFormat() && noteEditor.cursorPosition > 0) {
                        // Apply pre-format to newly typed character
                        noteEditor.applyingFormat = true;
                        format.applyPreFormatToTyped();
                        noteEditor.applyingFormat = false;
                    }
                    noteEditor.lastLength = noteEditor.length;
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: true
            }
        }
    }
}
