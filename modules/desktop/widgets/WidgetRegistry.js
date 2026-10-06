.pragma library

// Desktop widget types. A widget that also exists in the dashboard (calendar,
// weather) is the shared bento widget: `shared` names its entry in
// modules/widgets/dashboard/widgets/WidgetRegistry.js and there is one
// implementation. A desktop-only widget is one QML file in types/ (root
// extends DesktopWidget.qml) + one entry below (+ its labelKey/descKey and
// option label translations).
//
// Entry fields:
//   id        config value (desktop.widgets[].type)
//   labelKey  I18n key of the name; descKey: one-line description
//   icon      Icons.* name
//   file      QML file in types/ (desktop-only widgets)
//   shared    id of the shared bento widget to load instead of `file`
//   size      default size in px on a 1440p-tall screen ({w, h}); scaled
//             to the actual screen when the widget is added
//   minSize   smallest size in px (resizing stops there)
//   options   [{key, type: "toggle" | "select", default, labelKey,
//              choices: [{value, labelKey}]}] edited generically in settings
//             (types may also keep extra non-UI options, e.g. the note text)
//
// A placed widget (desktop.widgets[]) is
//   {id, type, monitor, x, y, w, h, options}
// with x/y/w/h fractions of its screen (0..1), so a layout survives a
// resolution change; `monitor` is the output name ("" or unknown = the
// first screen, so presets work on any machine).

var REFERENCE_HEIGHT = 1440;

// StyledRect variants offered for widget surfaces (glass variants).
var VARIANTS = ["pane", "common", "popup", "internalbg", "bg"];

var types = [
    {
        id: "media",
        labelKey: "desktop.widgets.type.media",
        descKey: "desktop.widgets.type.media.desc",
        icon: "musicNotes",
        file: "MediaWidget.qml",
        size: { w: 480, h: 168 },
        minSize: { w: 300, h: 120 },
        options: [
            { key: "showArt", type: "toggle", default: true, labelKey: "desktop.widgets.opt.show_art" },
            { key: "visualizer", type: "toggle", default: true, labelKey: "desktop.widgets.opt.visualizer" }
        ]
    },
    {
        id: "calendar",
        labelKey: "desktop.widgets.type.calendar",
        descKey: "desktop.widgets.type.calendar.desc",
        icon: "calendar",
        shared: "calendar",
        size: { w: 360, h: 360 },
        minSize: { w: 240, h: 240 },
        options: [
            { key: "showEvents", type: "toggle", default: true, labelKey: "desktop.widgets.opt.show_events" },
            {
                key: "weekStart", type: "select", default: "locale", labelKey: "desktop.widgets.opt.week_start",
                choices: [
                    { value: "locale", labelKey: "common.auto" },
                    { value: "monday", labelKey: "desktop.widgets.opt.week_start.monday" },
                    { value: "sunday", labelKey: "desktop.widgets.opt.week_start.sunday" }
                ]
            }
        ]
    },
    {
        id: "system",
        labelKey: "desktop.widgets.type.system",
        descKey: "desktop.widgets.type.system.desc",
        icon: "cpu",
        file: "SystemWidget.qml",
        size: { w: 360, h: 216 },
        minSize: { w: 240, h: 144 },
        options: [
            { key: "cpu", type: "toggle", default: true, labelKey: "desktop.widgets.opt.cpu" },
            { key: "ram", type: "toggle", default: true, labelKey: "desktop.widgets.opt.ram" },
            { key: "gpuTemp", type: "toggle", default: true, labelKey: "desktop.widgets.opt.gpu_temp" },
            { key: "net", type: "toggle", default: true, labelKey: "desktop.widgets.opt.net" }
        ]
    },
    {
        id: "note",
        labelKey: "desktop.widgets.type.note",
        descKey: "desktop.widgets.type.note.desc",
        icon: "note",
        file: "NoteWidget.qml",
        size: { w: 288, h: 288 },
        minSize: { w: 168, h: 144 },
        options: [
            {
                key: "tint", type: "select", default: "tertiary", labelKey: "desktop.widgets.opt.tint",
                choices: [
                    { value: "none", labelKey: "desktop.widgets.opt.tint.none" },
                    { value: "primary", labelKey: "desktop.widgets.opt.tint.primary" },
                    { value: "secondary", labelKey: "desktop.widgets.opt.tint.secondary" },
                    { value: "tertiary", labelKey: "desktop.widgets.opt.tint.tertiary" }
                ]
            }
        ]
    },
    {
        id: "weather",
        labelKey: "desktop.widgets.type.weather",
        descKey: "desktop.widgets.type.weather.desc",
        icon: "sun",
        shared: "weather",
        size: { w: 360, h: 192 },
        minSize: { w: 216, h: 120 },
        options: []
    }
];

function ids() {
    return types.map(function (t) {
        return t.id;
    });
}

function has(id) {
    return ids().indexOf(id) !== -1;
}

// null for unknown types (such widgets are skipped, never rendered).
function get(id) {
    for (var i = 0; i < types.length; i++) {
        if (types[i].id === id)
            return types[i];
    }
    return null;
}

function defaultOptions(id) {
    var t = get(id);
    var out = {};
    if (!t)
        return out;
    t.options.forEach(function (o) {
        out[o.key] = o.default;
    });
    return out;
}

// Options of a placed widget with every declared option filled in.
function options(widget) {
    var out = defaultOptions(widget ? widget.type : "");
    var own = widget && widget.options && typeof widget.options === "object" ? widget.options : {};
    for (var k in own)
        out[k] = own[k];
    return out;
}

function option(widget, key) {
    return options(widget)[key];
}

// Smallest size of a type as a fraction of a screen.
function minFraction(id, screenW, screenH) {
    var t = get(id);
    var k = scaleFor(screenH);
    var m = t ? t.minSize : { w: 120, h: 96 };
    return {
        w: Math.min(1, m.w * k / Math.max(1, screenW)),
        h: Math.min(1, m.h * k / Math.max(1, screenH))
    };
}

// Default size of a type as a fraction of a screen.
function sizeFraction(id, screenW, screenH) {
    var t = get(id);
    var k = scaleFor(screenH);
    var s = t ? t.size : { w: 320, h: 200 };
    return {
        w: Math.min(1, s.w * k / Math.max(1, screenW)),
        h: Math.min(1, s.h * k / Math.max(1, screenH))
    };
}

// Reference sizes are for 1440p; smaller screens get smaller widgets, but
// never below 0.6 (they would stop being readable).
function scaleFor(screenH) {
    return Math.max(0.6, Math.min(2, (screenH || REFERENCE_HEIGHT) / REFERENCE_HEIGHT));
}

function clamp01(v, fallback) {
    var n = Number(v);
    if (!isFinite(n))
        return fallback;
    return Math.max(0, Math.min(1, n));
}

var _seq = 0;
function newId(type) {
    _seq++;
    return type + "-" + Date.now().toString(36) + _seq.toString(36);
}

// A config entry made safe: known type, numbers in range, inside the
// screen, an id and an options object. Returns null for unknown types.
function normalize(w) {
    if (!w || typeof w !== "object" || !has(w.type))
        return null;
    var width = clamp01(w.w, 0.2);
    var height = clamp01(w.h, 0.2);
    width = Math.max(0.02, width);
    height = Math.max(0.02, height);
    var x = Math.min(clamp01(w.x, 0), 1 - width);
    var y = Math.min(clamp01(w.y, 0), 1 - height);
    return {
        id: typeof w.id === "string" && w.id !== "" ? w.id : w.type + "-" + Math.round(x * 1e4) + "-" + Math.round(y * 1e4),
        type: w.type,
        monitor: typeof w.monitor === "string" ? w.monitor : "",
        x: x,
        y: y,
        w: width,
        h: height,
        options: w.options && typeof w.options === "object" && !Array.isArray(w.options) ? w.options : {}
    };
}

function normalizeList(list) {
    var out = [];
    var seen = {};
    (list || []).forEach(function (w) {
        var n = normalize(w);
        if (!n)
            return;
        while (seen[n.id])
            n.id = n.id + "~";
        seen[n.id] = true;
        out.push(n);
    });
    return out;
}
