.pragma library

// Menu styles shown off the notch (layout.powermenu.style,
// layout.tools.style; HostRouter routes them to "overlay"). Files are
// relative to MenuOverlay.qml; "notch" styles live in the notch views.

var FILES = {
    "powermenu": {
        "fullscreen": "../powermenu/styles/Fullscreen.qml",
        "radial": "../powermenu/styles/Radial.qml"
    },
    "tools": {
        "radial": "../tools/styles/Radial.qml"
    }
};

var MODULES = Object.keys(FILES);

function fileFor(module, style) {
    var m = FILES[module];
    return m && m[style] ? m[style] : "";
}

// Styles that open at the pointer.
function atCursor(style) {
    return style === "radial";
}

// `yozd system get-cursor-position` output ({"x": .., "y": ..}, global
// coordinates) as a point on the screen at `origin` ({x, y}); null when
// unreadable.
function parseCursor(text, origin) {
    var m = /"x"\s*:\s*(-?\d+)[\s\S]*?"y"\s*:\s*(-?\d+)/.exec(text || "");
    if (!m)
        return null;
    var o = origin || { x: 0, y: 0 };
    return { x: parseInt(m[1], 10) - (o.x || 0), y: parseInt(m[2], 10) - (o.y || 0) };
}
