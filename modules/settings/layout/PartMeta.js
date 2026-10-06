.pragma library
.import "../../shell/LayoutModel.js" as LayoutModel
.import "../../bar/panels/PanelStyles.js" as PanelStyles

// Presentation of the layout builder's parts: names, icons and the
// selector options of their styles and aligns (values from LayoutModel).
// Tested in tests/layout-model.test.cjs.

var PARTS = {
    "bar": { "label": "prefs.layout.part.bar", "icon": "alignJustify", "desc": "prefs.layout.part.bar.desc" },
    "notch": { "label": "prefs.layout.part.notch", "icon": "dotsThree", "desc": "prefs.layout.part.notch.desc" },
    "dock": { "label": "prefs.layout.part.dock", "icon": "dock", "desc": "prefs.layout.part.dock.desc" }
};

var _STYLE_LABELS = {
    "notch": {
        "attached": ["prefs.notch.style.attached", "frameCorners"],
        "island": ["shell.dock.island", "appWindow"],
        "pill": ["prefs.notch.style.pill", "minus"]
    },
    "dock": {
        "default": ["prefs.layout.style.default", "dock"],
        "floating": ["shell.dock.floating", "appWindow"],
        "integrated": ["shell.dock.integrated", "stack"]
    }
};

var _ALIGN_LABELS = {
    "fill": ["prefs.layout.align.fill", "arrowsOut"],
    "start": ["prefs.notch.align.start", "alignLeft"],
    "center": ["prefs.notch.align.center", "alignCenter"],
    "end": ["prefs.notch.align.end", "alignRight"]
};

// Display order of the parts in the builder's controls.
var ORDER = ["bar", "notch", "dock"];

function part(id) {
    return PARTS[id] || { "label": "", "icon": "", "desc": "" };
}

// [{value, label, icon}] for SelectorControl
function styleOptions(id) {
    return LayoutModel.stylesOf(id).map(function (s) {
        if (id === "bar") {
            var meta = PanelStyles.get(s);
            return { "value": s, "label": meta.label, "icon": meta.icon };
        }
        var l = _STYLE_LABELS[id][s];
        return { "value": s, "label": l[0], "icon": l[1] };
    });
}

function alignOptions(id) {
    return LayoutModel.alignsOf(id).map(function (a) {
        return { "value": a, "label": _ALIGN_LABELS[a][0], "icon": _ALIGN_LABELS[a][1] };
    });
}

function edgeOptions(id) {
    var icons = { "top": "arrowUp", "bottom": "arrowDown", "left": "arrowLeft", "right": "arrowRight" };
    return LayoutModel.edgesOf(id).map(function (e) {
        return { "value": e, "label": "common." + e, "icon": icons[e] };
    });
}
