.pragma library

// Text that is about to be typed into the focused window (selection
// "replace"). A line break typed into a terminal runs a command and control
// characters can drive it, so they never reach wtype: line terminators are
// reported as multiline (the caller copies instead of typing) and other
// control characters are dropped.
function forTyping(s) {
    var text = String(s === undefined || s === null ? "" : s).replace(/(\r\n|\r|\n|\u2028|\u2029)+$/, "");
    var multiline = /[\r\n\u2028\u2029\u0085]/.test(text);
    // C0/C1 controls and DEL, except tab and line breaks.
    text = text.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f-\u0084\u0086-\u009f]/g, "");
    return { text: text, multiline: multiline };
}
