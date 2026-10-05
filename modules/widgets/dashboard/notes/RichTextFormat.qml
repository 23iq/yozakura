import QtQuick
import QtQuick.Controls
import qs.config

// Character formatting of the rich text note editor: toggles bold/italic/
// underline/strikeout and the font size on the selection, or, without a
// selection, records a "pre-format" applied to the next typed characters.
QtObject {
    id: format

    required property TextArea editor

    // Pre-format state (for typing with format when no selection)
    // null = inherit from cursor position, true/false = explicit state
    property var preFormatBold: null
    property var preFormatItalic: null
    property var preFormatUnderline: null
    property var preFormatStrikeout: null
    property var preFormatFontSize: null

    // Check if there's a text selection
    function hasSelection() {
        return format.editor.selectionStart !== format.editor.selectionEnd;
    }

    // Toggle bold (handles both selection and pre-format)
    function toggleBold() {
        if (hasSelection()) {
            format.editor.cursorSelection.font.bold = !format.editor.cursorSelection.font.bold;
        } else {
            // Toggle based on current visual state
            preFormatBold = !isBold();
        }
        format.editor.forceActiveFocus();
    }

    // Toggle italic
    function toggleItalic() {
        if (hasSelection()) {
            format.editor.cursorSelection.font.italic = !format.editor.cursorSelection.font.italic;
        } else {
            preFormatItalic = !isItalic();
        }
        format.editor.forceActiveFocus();
    }

    // Toggle underline
    function toggleUnderline() {
        if (hasSelection()) {
            format.editor.cursorSelection.font.underline = !format.editor.cursorSelection.font.underline;
        } else {
            preFormatUnderline = !isUnderline();
        }
        format.editor.forceActiveFocus();
    }

    // Toggle strikeout
    function toggleStrikeout() {
        if (hasSelection()) {
            format.editor.cursorSelection.font.strikeout = !format.editor.cursorSelection.font.strikeout;
        } else {
            preFormatStrikeout = !isStrikeout();
        }
        format.editor.forceActiveFocus();
    }

    // Set font size preserving individual character styles
    function setFontSize(size) {
        if (hasSelection()) {
            let start = format.editor.selectionStart;
            let end = format.editor.selectionEnd;

            // Process each character: get its font, change size, reassign
            for (let i = start; i < end; i++) {
                format.editor.select(i, i + 1);
                let charFont = format.editor.cursorSelection.font;
                charFont.pixelSize = size;
                format.editor.cursorSelection.font = charFont;
            }

            // Restore original selection
            format.editor.select(start, end);
        } else {
            preFormatFontSize = size;
        }
        format.editor.forceActiveFocus();
    }

    // Font size two steps up (+2, max 200) or down (-2, min 8)
    function stepFontSize(up) {
        let currentSize = getCurrentFontSize();
        setFontSize(up ? Math.min(200, currentSize + 2) : Math.max(8, currentSize - 2));
    }

    // Get current bold state (selection or pre-format or cursor)
    function isBold() {
        if (hasSelection()) {
            return format.editor.cursorSelection.font.bold;
        }
        if (preFormatBold !== null) {
            return preFormatBold;
        }
        // Inherit from cursor position
        return format.editor.cursorSelection.font.bold;
    }

    // Get current italic state
    function isItalic() {
        if (hasSelection()) {
            return format.editor.cursorSelection.font.italic;
        }
        if (preFormatItalic !== null) {
            return preFormatItalic;
        }
        return format.editor.cursorSelection.font.italic;
    }

    // Get current underline state
    function isUnderline() {
        if (hasSelection()) {
            return format.editor.cursorSelection.font.underline;
        }
        if (preFormatUnderline !== null) {
            return preFormatUnderline;
        }
        return format.editor.cursorSelection.font.underline;
    }

    // Get current strikeout state
    function isStrikeout() {
        if (hasSelection()) {
            return format.editor.cursorSelection.font.strikeout;
        }
        if (preFormatStrikeout !== null) {
            return preFormatStrikeout;
        }
        return format.editor.cursorSelection.font.strikeout;
    }

    // Get current font size
    function getCurrentFontSize() {
        if (hasSelection()) {
            return format.editor.cursorSelection.font.pixelSize || Config.theme.fontSize;
        }
        if (preFormatFontSize !== null) {
            return preFormatFontSize;
        }
        return format.editor.cursorSelection.font.pixelSize || Config.theme.fontSize;
    }

    // Check if any pre-format is active
    function hasActivePreFormat() {
        return preFormatBold !== null || preFormatItalic !== null || preFormatUnderline !== null || preFormatStrikeout !== null || preFormatFontSize !== null;
    }

    // Reset pre-format state
    function resetPreFormat() {
        preFormatBold = null;
        preFormatItalic = null;
        preFormatUnderline = null;
        preFormatStrikeout = null;
        preFormatFontSize = null;
    }

    // Apply the pre-format to the character just typed before the cursor
    function applyPreFormatToTyped() {
        let pos = format.editor.cursorPosition;
        if (pos <= 0)
            return;
        // Select the just-typed character
        format.editor.select(pos - 1, pos);
        // Apply explicit format states
        if (preFormatBold !== null)
            format.editor.cursorSelection.font.bold = preFormatBold;
        if (preFormatItalic !== null)
            format.editor.cursorSelection.font.italic = preFormatItalic;
        if (preFormatUnderline !== null)
            format.editor.cursorSelection.font.underline = preFormatUnderline;
        if (preFormatStrikeout !== null)
            format.editor.cursorSelection.font.strikeout = preFormatStrikeout;
        if (preFormatFontSize !== null)
            format.editor.cursorSelection.font.pixelSize = preFormatFontSize;
        // Deselect and move cursor back
        format.editor.cursorPosition = pos;
    }

    // Alt+Left / Alt+Right: step the paragraph alignment
    // Left <-> Center <-> Right <-> Justify (stops at both ends)
    function stepAlignment(forward) {
        let current = format.editor.cursorSelection.alignment;
        if (forward) {
            if (current === Qt.AlignLeft) {
                format.editor.cursorSelection.alignment = Qt.AlignHCenter;
            } else if (current === Qt.AlignHCenter) {
                format.editor.cursorSelection.alignment = Qt.AlignRight;
            } else if (current === Qt.AlignRight) {
                format.editor.cursorSelection.alignment = Qt.AlignJustify;
            }
        } else {
            if (current === Qt.AlignJustify) {
                format.editor.cursorSelection.alignment = Qt.AlignRight;
            } else if (current === Qt.AlignRight) {
                format.editor.cursorSelection.alignment = Qt.AlignHCenter;
            } else if (current === Qt.AlignHCenter) {
                format.editor.cursorSelection.alignment = Qt.AlignLeft;
            }
        }
    }

    function setAlignment(alignment) {
        format.editor.cursorSelection.alignment = alignment;
        format.editor.forceActiveFocus();
    }
}
