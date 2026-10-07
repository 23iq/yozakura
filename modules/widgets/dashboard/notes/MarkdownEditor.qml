import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.components.kit

// Editor of markdown (.md) notes: formatting toolbar (heading level, bold,
// italic, underline, strikethrough, code, link) and a split view of the
// plain text editor and its rendered preview with synced scrolling.
ColumnLayout {
    id: pane

    property string content: ""
    readonly property alias text: mdEditor.text

    // Emitted on every text change (the tab decides whether it is an edit)
    signal edited
    signal escapePressed

    function focusEditor() {
        mdEditor.forceActiveFocus();
    }

    spacing: 8

    MarkdownFormat {
        id: format
        editor: mdEditor
    }

    // Markdown formatting toolbar
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 40

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4

            // Heading level controls
            NoteToolButton {
                glyph: Icons.minus
                tooltip: "Decrease heading (Alt+Down)"
                onClicked: format.decreaseHeading()
            }

            KitText {
                Layout.preferredWidth: Space.controlS
                horizontalAlignment: Text.AlignHCenter
                role: "body"
                font.weight: Font.DemiBold
                text: format.currentHeading || "P"
            }

            NoteToolButton {
                glyph: Icons.plus
                tooltip: "Increase heading (Alt+Up)"
                onClicked: format.increaseHeading()
            }

            Divider {
                vertical: true
                Layout.preferredHeight: Space.l + Space.s
            }

            NoteToolButton {
                glyph: "B"
                glyphFont: Config.theme.font
                glyphBold: true
                tooltip: "Bold (Ctrl+B)"
                onClicked: format.toggleBold()
            }

            NoteToolButton {
                glyph: "I"
                glyphFont: Config.theme.font
                glyphItalic: true
                tooltip: "Italic (Ctrl+I)"
                onClicked: format.toggleItalic()
            }

            NoteToolButton {
                glyph: "U"
                glyphFont: Config.theme.font
                glyphUnderline: true
                tooltip: "Underline (Ctrl+U)"
                onClicked: format.toggleUnderline()
            }

            NoteToolButton {
                glyph: "S"
                glyphFont: Config.theme.font
                glyphStrikeout: true
                tooltip: "Strikethrough (Ctrl+D)"
                onClicked: format.toggleStrikethrough()
            }

            Divider {
                vertical: true
                Layout.preferredHeight: Space.l + Space.s
            }

            NoteToolButton {
                glyph: "<>"
                glyphFont: "monospace"
                tooltip: "Inline code (Ctrl+E)"
                onClicked: format.toggleCode()
            }

            NoteToolButton {
                glyph: Icons.link
                tooltip: "Insert link (Ctrl+K)"
                onClicked: format.insertLink()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    Divider {
        Layout.fillWidth: true
    }

    // Split view: Editor and Preview
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        // Markdown Editor
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: mdEditorFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: mdEditor.contentHeight + height * 0.5  // Extra bottom margin for scroll
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Flag to prevent sync loops
                property bool syncing: false

                // Sync editor scroll to preview
                function syncToPreview() {
                    if (mdEditorFlickable.syncing || !mdPreviewFlickable)
                        return;
                    mdEditorFlickable.syncing = true;
                    let ratio = mdEditorFlickable.contentHeight > mdEditorFlickable.height ? mdEditorFlickable.contentY / Math.max(1, mdEditorFlickable.contentHeight - mdEditorFlickable.height) : 0;
                    let targetY = ratio * (mdPreviewFlickable.contentHeight - mdPreviewFlickable.height);
                    if (mdPreviewFlickable.contentHeight > mdPreviewFlickable.height) {
                        mdPreviewFlickable.contentY = Math.max(0, Math.min(targetY, mdPreviewFlickable.contentHeight - mdPreviewFlickable.height));
                    }
                    mdEditorFlickable.syncing = false;
                }

                onContentYChanged: mdEditorFlickable.syncToPreview()

                TextArea.flickable: TextArea {
                    id: mdEditor
                    text: pane.content
                    textFormat: TextEdit.PlainText
                    font.family: Config.theme.monoFont
                    font.pixelSize: Config.theme.monoFontSize
                    font.weight: Font.Medium
                    color: Colors.overSurface
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    placeholderText: I18n.t("notes.write_markdown")
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 8
                    bottomPadding: 8
                    background: Item {}

                    onTextChanged: {
                        pane.edited();
                        format.updateHeadingDisplay();
                        // Sync after text changes with small delay to let layout update
                        mdSyncTimer.restart();
                    }

                    onCursorPositionChanged: {
                        format.updateHeadingDisplay();
                        // Ensure cursor is visible and sync preview
                        mdSyncTimer.restart();
                    }

                    // Timer to debounce sync calls
                    Timer {
                        id: mdSyncTimer
                        interval: 50
                        repeat: false
                        onTriggered: {
                            // Make sure cursor is visible in editor
                            let cursorRect = mdEditor.cursorRectangle;
                            if (cursorRect.y < mdEditorFlickable.contentY) {
                                mdEditorFlickable.contentY = Math.max(0, cursorRect.y - 20);
                            } else if (cursorRect.y + cursorRect.height > mdEditorFlickable.contentY + mdEditorFlickable.height) {
                                mdEditorFlickable.contentY = Math.min(mdEditorFlickable.contentHeight - mdEditorFlickable.height, cursorRect.y + cursorRect.height - mdEditorFlickable.height + 20);
                            }
                            // Sync will happen via onContentYChanged
                        }
                    }

                    Keys.onEscapePressed: pane.escapePressed()

                    // Markdown formatting shortcuts
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
                                format.toggleStrikethrough();
                                event.accepted = true;
                                break;
                            case Qt.Key_E:
                                format.toggleCode();
                                event.accepted = true;
                                break;
                            case Qt.Key_K:
                                format.insertLink();
                                event.accepted = true;
                                break;
                            }
                        }
                        if (event.modifiers & Qt.AltModifier) {
                            if (event.key === Qt.Key_Up) {
                                format.increaseHeading();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                format.decreaseHeading();
                                event.accepted = true;
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                }
            }
        }

        Divider {
            vertical: true
            Layout.fillHeight: true
        }

        // Markdown Preview
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: mdPreviewFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: mdPreviewText.contentHeight + height * 0.5  // Extra bottom margin for scroll
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Sync preview scroll to editor (only on manual interaction)
                onContentYChanged: {
                    if ((mdPreviewFlickable.moving || mdPreviewFlickable.dragging) && !mdEditorFlickable.syncing) {
                        mdEditorFlickable.syncing = true;
                        let ratio = mdPreviewFlickable.contentHeight > mdPreviewFlickable.height ? mdPreviewFlickable.contentY / Math.max(1, mdPreviewFlickable.contentHeight - mdPreviewFlickable.height) : 0;
                        let targetY = ratio * (mdEditorFlickable.contentHeight - mdEditorFlickable.height);
                        if (mdEditorFlickable.contentHeight > mdEditorFlickable.height) {
                            mdEditorFlickable.contentY = Math.max(0, Math.min(targetY, mdEditorFlickable.contentHeight - mdEditorFlickable.height));
                        }
                        mdEditorFlickable.syncing = false;
                    }
                }

                TextEdit {
                    id: mdPreviewText
                    width: mdPreviewFlickable.width - 16
                    x: 8
                    y: 8
                    textFormat: TextEdit.MarkdownText
                    text: mdEditor.text
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.overSurface
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                    selectByMouse: true
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                }
            }
        }
    }
}
