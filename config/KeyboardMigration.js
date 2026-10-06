.pragma library

// keyboard.json written before keyboard.managed existed
// (tests/keyboard-model.test.cjs). The shell used to create the file with
// the pure defaults on first start and push them over the user's own
// compositor settings; such a file was never chosen by the user, so it
// stays unmanaged. A file that differs from the defaults was edited (in
// Yozakura or by hand) and keeps being managed.

// Keys that reach the compositor (showIndicator is the shell's own).
var COMPOSITOR_KEYS = ["layouts", "switchBind", "options", "repeatRate", "repeatDelay"];

function _layouts(list) {
    return Array.prototype.slice.call(list || []).map(function (l) {
        return {
            "layout": String((l && l.layout) || ""),
            "variant": String((l && l.variant) || "")
        };
    });
}

function _same(key, a, b) {
    if (key === "layouts")
        return JSON.stringify(_layouts(a)) === JSON.stringify(_layouts(b));
    return JSON.stringify(a === undefined ? null : a) === JSON.stringify(b === undefined ? null : b);
}

// The managed value for a parsed keyboard.json without the key: true when
// any compositor key differs from `defaults` (a missing key counts as the
// default). null when the document already has it or is not an object.
function legacyManaged(doc, defaults) {
    if (!doc || typeof doc !== "object" || Array.isArray(doc) || doc.managed !== undefined)
        return null;
    return COMPOSITOR_KEYS.some(function (k) {
        return doc[k] !== undefined && !_same(k, doc[k], defaults[k]);
    });
}
