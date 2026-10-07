.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/bar.js (format: config/meta/Meta.js).

var description = "The bar (panel): style (classic/islands), module layout, screen edge, frame, clock, auto-hide.";

var keys = {
    "position": {
        "enum": Enums.EDGES,
        "description": "Screen edge the bar sits on (left/right make it vertical)."
    },
    "launcherIcon": {
        "format": "icon",
        "description": "Launcher button icon (icon name or image path); empty uses the app logo."
    },
    "launcherIconTint": {
        "description": "Tint the launcher icon with the palette."
    },
    "launcherIconSize": {
        "min": 8,
        "max": 64,
        "unit": "px",
        "description": "Launcher icon size."
    },
    "screenList": {
        "items": {
            "type": "string"
        },
        "description": "Monitor names to show the bar on; empty = every monitor."
    },
    "enableFirefoxPlayer": {
        "description": "Show Firefox as a media player (MPRIS); off hides it."
    },
    "frameEnabled": {
        "description": "Draw a frame around the screen edges joined with the bar."
    },
    "frameThickness": {
        "min": 0,
        "max": 40,
        "unit": "px",
        "description": "Thickness of the screen frame."
    },
    "pinnedOnStartup": {
        "description": "Bar starts pinned (always visible); unpinned it auto-hides."
    },
    "hoverToReveal": {
        "description": "Reveal the unpinned bar when the pointer touches its screen edge."
    },
    "hoverRegionHeight": {
        "min": 0,
        "max": 40,
        "unit": "px",
        "description": "Size of the invisible edge strip that reveals the hidden bar."
    },
    "showPinButton": {
        "description": "Show the pin (keep visible) button in the bar."
    },
    "availableOnFullscreen": {
        "description": "Allow revealing the bar over fullscreen windows."
    },
    "use12hFormat": {
        "description": "12-hour clock (AM/PM)."
    },
    "containBar": {
        "description": "Draw the bar inside the screen frame (frame on)."
    },
    "keepBarShadow": {
        "description": "Keep the bar shadow when it is contained in the frame."
    },
    "keepBarBorder": {
        "description": "Keep the bar border when it is contained in the frame."
    },
    "clockShowDate": {
        "description": "Show the date next to the time in the bar clock."
    },
    "compact": {
        "description": "Thinner bar with smaller paddings."
    },
    "layout": {
        "description": "Bar layout: style and the ordered module ids of each group."
    },
    "layout.style": {
        "enum": Enums.BAR_STYLES,
        "description": "Look of the bar (spec bar.style): classic (full width), floating, islands (edge tabs), pills, dock-like or none (no bar, nothing reserved); bar.panels entries take the same styles."
    },
    "layout.left": {
        "items": {
            "enum": Enums.BAR_MODULES
        },
        "uniqueItems": true,
        "description": "Modules at the start (left/top), in order."
    },
    "layout.right": {
        "items": {
            "enum": Enums.BAR_MODULES
        },
        "uniqueItems": true,
        "description": "Modules at the end (right/bottom), in order."
    },
    "layout.drawer": {
        "items": {
            "enum": Enums.BAR_MODULES
        },
        "uniqueItems": true,
        "description": "Modules tucked into the overflow drawer."
    },
    "panels": {
        "items": {
            "type": "object"
        },
        "description": "Bar panels (empty = the single bar from position/layout/screenList). Each item: {id, edge: top|bottom|left|right, style: " + Enums.BAR_STYLES.join("|") + ", groups: {start, center, end, drawer, gapStart, gapEnd: [module ids]}, align: fill|center|start|end, size (module px, 0 = style), thickness (px, 0 = auto), margin (px, -1 = style), flat (bool), autohide: auto|always|never, reserve (bool), screens ([] = all; names, primary, secondary), enabled, options: {surface: bg|bar|none}}. See modules/bar/panels/PanelLayout.js."
    },
    "moduleOptions": {
        "description": "Options of bar modules, shared by every panel showing them."
    },
    "moduleOptions.windowTitle.show": {
        "enum": ["both", "app", "title"],
        "description": "Window title module: app name, window title or both."
    },
    "moduleOptions.windowTitle.showIcon": {
        "description": "Window title module: show the app icon."
    },
    "moduleOptions.windowTitle.maxWidth": {
        "min": 80,
        "max": 2000,
        "unit": "px",
        "description": "Window title module: widest the title may get."
    },
    "moduleOptions.taskbar.showPinned": {
        "description": "Taskbar: show pinned apps that are not running."
    },
    "moduleOptions.taskbar.showLabels": {
        "description": "Taskbar (not in docks): show app names next to icons."
    },
    "moduleOptions.taskbar.indicator": {
        "enum": ["dot"],
        "description": "Taskbar: running-app indicator."
    },
    "moduleOptions.systemStats.items": {
        "items": {
            "enum": ["cpu", "ram", "gpu", "cpuTemp", "gpuTemp", "net"]
        },
        "uniqueItems": true,
        "description": "System stats module: metrics shown, in order."
    },
    "moduleOptions.weather.showDescription": {
        "description": "Weather module: show the condition text."
    },
    "moduleOptions.clock.showWeather": {
        "description": "Clock module: lead with the weather symbol (off: the day name, or nothing when the date is shown)."
    },
    "moduleOptions.clock.face": {
        "enum": ["digital", "stacked", "dotMatrix", "kanji"],
        "description": "Clock face: digital text, hours over minutes, 3x5 dot matrix or Japanese numerals (十時 二十五分). A vertical bar shows digital as stacked."
    },
    "moduleOptions.clock.pomodoroStyle": {
        "enum": ["ring", "underline", "countdown", "island"],
        "description": "Running Pomodoro on the clock: a progress ring, a progress line along the button, the mm:ss countdown, or nothing on the bar (the notch timers activity shows it)."
    },
    "moduleOptions.clock.panelStyle": {
        "enum": ["column", "wide", "bento"],
        "description": "Clock popup layout: a narrow column (time and weather, Pomodoro, world clocks, agenda), a wide two-pane card (time and weather beside a large Pomodoro ring, world clocks below), or the editable bento grid of widgets (moduleOptions.clock.panel.cells)."
    },
    "moduleOptions.clock.panel": {
        "description": "Clock popup panel."
    },
    "moduleOptions.clock.panel.cells": {
        "items": {
            "type": "object"
        },
        "description": "Placed clock panel widgets: [{widget, x, y, w, h}] on a 2-column grid; any bento widget id (weather, pomodoro, agenda, worldClocks, calendar, ...). Empty or invalid uses the default panel. Edited in place from the panel (pencil button)."
    },
    "moduleOptions.worldClocks.zones": {
        "items": {
            "type": "object"
        },
        "description": "World clocks: [{label, zone}] with IANA zone names (e.g. Asia/Tokyo)."
    },
    "moduleOptions.workspaceTags.brackets": {
        "description": "Workspace tags: draw [1][2][3] brackets."
    },
    "moduleOptions.downloads.folder": {
        "format": "path",
        "local": true,
        "description": "Downloads stack: folder (empty = ~/Downloads)."
    },
    "moduleOptions.downloads.count": {
        "min": 1,
        "max": 12,
        "description": "Downloads stack: recent files fanned out."
    },
    "moduleOptions.workspacePreviews.count": {
        "min": 1,
        "max": 10,
        "description": "Workspace previews: miniatures shown."
    }
};
