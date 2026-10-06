.pragma library

// Every module a bar panel can show, by id. Order is the presentation order
// in the settings (module palette).
//
//  icon   Icons.qml name, label/desc translation keys (settings palette)
//  file   module component, relative to modules/bar/. Built-in modules
//         without `file` have a hand-wired Component in BarModuleSlot.qml.
//
// Adding a module = one QML file under modules/bar/modules/ (root Item with
// `bar`, `startRadius`, `endRadius`, `enableShadow`; see BarModuleSurface.qml)
// + one entry here + its label translations.
var MODULES = [
    {
        "id": "launcher",
        "icon": "apps",
        "label": "prefs.bar.module.launcher"
    },
    {
        "id": "workspaces",
        "icon": "squaresFour",
        "label": "prefs.bar.module.workspaces"
    },
    {
        "id": "workspaceTags",
        "icon": "textT",
        "label": "prefs.bar.module.workspaceTags",
        "file": "modules/WorkspaceTags.qml"
    },
    {
        "id": "layoutSelector",
        "icon": "dwindle",
        "label": "prefs.bar.module.layoutSelector"
    },
    {
        "id": "pin",
        "icon": "pin",
        "label": "prefs.bar.module.pin"
    },
    {
        "id": "windowTitle",
        "icon": "appWindow",
        "label": "prefs.bar.module.windowTitle",
        "file": "modules/WindowTitle.qml"
    },
    {
        "id": "appMenu",
        "icon": "list",
        "label": "prefs.bar.module.appMenu",
        "file": "modules/AppMenu.qml"
    },
    {
        "id": "taskbar",
        "icon": "dock",
        "label": "prefs.bar.module.taskbar",
        "file": "modules/Taskbar.qml"
    },
    {
        "id": "downloads",
        "icon": "downloadSimple",
        "label": "prefs.bar.module.downloads",
        "file": "modules/DownloadsStack.qml"
    },
    {
        "id": "workspacePreviews",
        "icon": "columns",
        "label": "prefs.bar.module.workspacePreviews",
        "file": "modules/WorkspacePreviews.qml"
    },
    {
        "id": "presets",
        "icon": "magicWand",
        "label": "prefs.bar.module.presets"
    },
    {
        "id": "tools",
        "icon": "toolbox",
        "label": "prefs.bar.module.tools"
    },
    {
        "id": "systray",
        "icon": "dotsNine",
        "label": "prefs.bar.module.systray"
    },
    {
        "id": "systemStats",
        "icon": "cpu",
        "label": "prefs.bar.module.systemStats",
        "file": "modules/SystemStats.qml"
    },
    {
        "id": "weather",
        "icon": "sun",
        "label": "prefs.bar.module.weather",
        "file": "modules/WeatherChip.qml"
    },
    {
        "id": "worldClocks",
        "icon": "globe",
        "label": "prefs.bar.module.worldClocks",
        "file": "modules/WorldClocks.qml"
    },
    {
        "id": "keyboardLayout",
        "icon": "keyboard",
        "label": "prefs.bar.module.keyboardLayout",
        "file": "modules/KeyboardLayoutIndicator.qml"
    },
    {
        "id": "controls",
        "icon": "faders",
        "label": "prefs.bar.module.controls"
    },
    {
        "id": "battery",
        "icon": "batteryHigh",
        "label": "prefs.bar.module.battery"
    },
    {
        "id": "clock",
        "icon": "clock",
        "label": "prefs.bar.module.clock"
    },
    {
        "id": "power",
        "icon": "power",
        "label": "prefs.bar.module.power"
    }
];

var _byId = {};
for (var _i = 0; _i < MODULES.length; _i++)
    _byId[MODULES[_i].id] = MODULES[_i];

function ids() {
    return MODULES.map(function (m) {
        return m.id;
    });
}

function has(id) {
    return _byId[id] !== undefined;
}

function get(id) {
    return _byId[id] || null;
}

// Component file (relative to modules/bar/) of a file-based module, or "".
function file(id) {
    var m = _byId[id];
    return m && m.file ? m.file : "";
}
