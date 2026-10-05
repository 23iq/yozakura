import QtQuick
import QtQuick.Controls

// Markdown formatting of the markdown note editor: wraps the selection in
// markers (bold, italic, underline, strikethrough, code), inserts links and
// changes the heading level of the current line.
QtObject {
    id: format

    required property TextArea editor

    // Property to track current heading level at cursor
    property string currentHeading: "P"

    // Wrap selected text with markers, or insert markers at cursor
    function wrapSelection(prefix, suffix) {
        if (!format.editor)
            return;

        let start = format.editor.selectionStart;
        let end = format.editor.selectionEnd;
        let text = format.editor.text;

        if (start === end) {
            // No selection - insert markers and place cursor between them
            let newText = text.substring(0, start) + prefix + suffix + text.substring(end);
            format.editor.text = newText;
            format.editor.cursorPosition = start + prefix.length;
        } else {
            // Has selection - check if already wrapped
            let selectedText = text.substring(start, end);
            let beforeStart = text.substring(Math.max(0, start - prefix.length), start);
            let afterEnd = text.substring(end, Math.min(text.length, end + suffix.length));

            if (beforeStart === prefix && afterEnd === suffix) {
                // Already wrapped - unwrap
                let newText = text.substring(0, start - prefix.length) + selectedText + text.substring(end + suffix.length);
                format.editor.text = newText;
                format.editor.select(start - prefix.length, end - prefix.length);
            } else if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix)) {
                // Selection includes markers - remove them
                let unwrapped = selectedText.substring(prefix.length, selectedText.length - suffix.length);
                let newText = text.substring(0, start) + unwrapped + text.substring(end);
                format.editor.text = newText;
                format.editor.select(start, start + unwrapped.length);
            } else {
                // Wrap selection
                let newText = text.substring(0, start) + prefix + selectedText + suffix + text.substring(end);
                format.editor.text = newText;
                format.editor.select(start + prefix.length, end + prefix.length);
            }
        }
        format.editor.forceActiveFocus();
    }

    function toggleBold() {
        wrapSelection("**", "**");
    }

    function toggleItalic() {
        wrapSelection("*", "*");
    }

    function toggleUnderline() {
        wrapSelection("__", "__");
    }

    function toggleStrikethrough() {
        wrapSelection("~~", "~~");
    }

    function toggleCode() {
        wrapSelection("`", "`");
    }

    function insertLink() {
        if (!format.editor)
            return;

        let start = format.editor.selectionStart;
        let end = format.editor.selectionEnd;
        let text = format.editor.text;

        if (start === end) {
            // No selection - insert link template
            let linkTemplate = "[text](url)";
            let newText = text.substring(0, start) + linkTemplate + text.substring(end);
            format.editor.text = newText;
            // Select "text" for easy replacement
            format.editor.select(start + 1, start + 5);
        } else {
            // Use selection as link text
            let selectedText = text.substring(start, end);
            let linkText = "[" + selectedText + "](url)";
            let newText = text.substring(0, start) + linkText + text.substring(end);
            format.editor.text = newText;
            // Select "url" for easy replacement
            format.editor.select(start + selectedText.length + 3, start + selectedText.length + 6);
        }
        format.editor.forceActiveFocus();
    }

    // Get current line info
    function getCurrentLine() {
        if (!format.editor)
            return {
                start: 0,
                end: 0,
                text: "",
                lineNumber: 0
            };

        let text = format.editor.text;
        let pos = format.editor.cursorPosition;

        // Find line start
        let lineStart = pos;
        while (lineStart > 0 && text[lineStart - 1] !== '\n') {
            lineStart--;
        }

        // Find line end
        let lineEnd = pos;
        while (lineEnd < text.length && text[lineEnd] !== '\n') {
            lineEnd++;
        }

        return {
            start: lineStart,
            end: lineEnd,
            text: text.substring(lineStart, lineEnd)
        };
    }

    // Get heading level of current line (0 = no heading, 1-6 = H1-H6)
    function getHeadingLevel(lineText) {
        let match = lineText.match(/^(#{1,6})\s/);
        if (match) {
            return match[1].length;
        }
        return 0;
    }

    // Update heading display
    function updateHeadingDisplay() {
        let line = getCurrentLine();
        let level = getHeadingLevel(line.text);
        currentHeading = level > 0 ? ("H" + level) : "P";
    }

    function setHeadingLevel(level) {
        if (!format.editor)
            return;

        let line = getCurrentLine();
        let text = format.editor.text;

        // Remove existing heading markers
        let lineContent = line.text.replace(/^#{1,6}\s*/, '');

        // Add new heading markers
        let newLine;
        if (level === 0) {
            newLine = lineContent;
        } else {
            newLine = '#'.repeat(level) + ' ' + lineContent;
        }

        let newText = text.substring(0, line.start) + newLine + text.substring(line.end);
        let cursorOffset = level > 0 ? level + 1 : 0;

        format.editor.text = newText;
        format.editor.cursorPosition = line.start + cursorOffset + lineContent.length;
        updateHeadingDisplay();
        format.editor.forceActiveFocus();
    }

    function increaseHeading() {
        let line = getCurrentLine();
        let currentLevel = getHeadingLevel(line.text);
        if (currentLevel < 6) {
            setHeadingLevel(currentLevel + 1);
        }
    }

    function decreaseHeading() {
        let line = getCurrentLine();
        let currentLevel = getHeadingLevel(line.text);
        if (currentLevel > 0) {
            setHeadingLevel(currentLevel - 1);
        }
    }
}
