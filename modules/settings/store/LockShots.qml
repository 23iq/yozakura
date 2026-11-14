pragma Singleton

import QtQuick
import Quickshell

// The lock screen style pictures of the settings window, kept for the
// session (editors/LockStyleGallery.qml): a picture taken once for a style
// and what it shows (`look`: wallpaper, tone, position...) is shown at
// once on the next visit of the Lock screen tab instead of being taken
// again. Holds the grab results (their `url` stays valid while held).
Singleton {
    id: root

    // "style|look" -> ItemGrabResult
    property var shots: ({})

    function key(style, look) {
        return String(style) + "|" + String(look);
    }
    function get(style, look) {
        return root.shots[root.key(style, look)] || null;
    }
    // (pictures of an older look are let go)
    function put(style, look, result) {
        const next = {};
        const tail = "|" + String(look);
        Object.keys(root.shots).forEach(k => {
            if (k.endsWith(tail))
                next[k] = root.shots[k];
        });
        next[root.key(style, look)] = result;
        root.shots = next;
    }
}
