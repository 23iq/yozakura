.pragma library
.import "barextra.js" as BarExtra

// Bar & Islands: style, module layout, placement, clock, workspaces and
// auto-hide. Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "bar",
    "icon": "squaresFour",
    "title": "prefs.cat.bar",
    "description": "prefs.cat.bar.desc",
    "keywords": "bar panel taskbar islands top modules widgets",
    "sections": [
        {
            "id": "panels",
            "title": "prefs.bar.section.panels",
            "entries": [
                {
                    "id": "bar.panels.editor",
                    "type": "custom",
                    "component": "PanelsEditor",
                    "keys": ["bar.panels"],
                    "label": "prefs.bar.panels",
                    "description": "prefs.bar.panels.desc",
                    "keywords": "panels layout bars edge style dock menubar taskbar rail corners statusline ribbon two bars multi monitor modules"
                }
            ]
        },
        {
            "id": "style",
            "title": "prefs.bar.section.style",
            "entries": [
                {
                    "key": "bar.layout.style",
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": true
                    },
                    "type": "custom",
                    "component": "BarStyleCards",
                    "label": "prefs.bar.style",
                    "description": "prefs.bar.style.desc",
                    "keywords": "classic islands floating pills style look"
                },
                {
                    "key": "bar.compact",
                    "type": "toggle",
                    "label": "prefs.bar.compact",
                    "description": "prefs.bar.compact.desc",
                    "keywords": "compact dense slim thin small height"
                }
            ]
        },
        {
            "id": "layout",
            "title": "prefs.bar.section.layout",
            "entries": [
                {
                    "id": "bar.layout.modules",
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": true
                    },
                    "type": "custom",
                    "component": "BarLayoutEditor",
                    "keys": ["bar.layout.left", "bar.layout.right", "bar.layout.drawer"],
                    "label": "prefs.bar.layout",
                    "description": "prefs.bar.layout.desc",
                    "keywords": "modules widgets order arrange drag drop drawer left right add remove launcher clock battery tray"
                }
            ]
        },
        {
            "id": "placement",
            "title": "prefs.bar.section.placement",
            "entries": [
                {
                    "key": "bar.position",
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": true
                    },
                    "type": "custom",
                    "component": "BarPositionPicker",
                    "label": "prefs.bar.position",
                    "description": "prefs.bar.position.desc",
                    "keywords": "position edge top bottom left right vertical horizontal"
                },
                {
                    "key": "bar.frameEnabled",
                    "type": "toggle",
                    "label": "prefs.bar.frame",
                    "description": "prefs.bar.frame.desc",
                    "keywords": "frame border screen edge outline"
                },
                {
                    "key": "bar.frameThickness",
                    "type": "slider",
                    "min": 0,
                    "max": 40,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": {
                        "key": "bar.frameEnabled",
                        "equals": true
                    },
                    "label": "prefs.bar.frame_thickness",
                    "description": "prefs.bar.frame_thickness.desc",
                    "keywords": "frame thickness width border size"
                },
                {
                    "key": "bar.containBar",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "bar.frameEnabled",
                        "equals": true
                    },
                    "label": "prefs.bar.contain_bar",
                    "description": "prefs.bar.contain_bar.desc",
                    "keywords": "frame contain inside bar"
                }
            ]
        },
        {
            "id": "clock",
            "title": "prefs.bar.section.clock",
            "entries": [
                {
                    "key": "bar.clockShowDate",
                    "type": "toggle",
                    "preview": "ClockPreview",
                    "label": "prefs.bar.clock_date",
                    "description": "prefs.bar.clock_date.desc",
                    "keywords": "clock date day month time"
                },
                {
                    "key": "bar.use12hFormat",
                    "type": "toggle",
                    "label": "prefs.bar.clock_12h",
                    "description": "prefs.bar.clock_12h.desc",
                    "keywords": "clock 12h am pm 24h time format"
                },
                {
                    "key": "bar.moduleOptions.clock.face",
                    "type": "selector",
                    "label": "prefs.bar.clock_face",
                    "description": "prefs.bar.clock_face.desc",
                    "keywords": "clock face style digital stacked dot matrix led kanji japanese",
                    "options": [
                        { "value": "digital", "label": "prefs.bar.clock_face.digital" },
                        { "value": "stacked", "label": "prefs.bar.clock_face.stacked" },
                        { "value": "dotMatrix", "label": "prefs.bar.clock_face.dotMatrix" },
                        { "value": "kanji", "label": "prefs.bar.clock_face.kanji" }
                    ]
                },
                {
                    "key": "bar.moduleOptions.clock.pomodoroStyle",
                    "type": "selector",
                    "label": "prefs.bar.pomodoro_style",
                    "description": "prefs.bar.pomodoro_style.desc",
                    "keywords": "pomodoro focus timer ring underline countdown island progress clock",
                    "options": [
                        { "value": "ring", "label": "prefs.bar.pomodoro_style.ring" },
                        { "value": "underline", "label": "prefs.bar.pomodoro_style.underline" },
                        { "value": "countdown", "label": "prefs.bar.pomodoro_style.countdown" },
                        { "value": "island", "label": "prefs.bar.pomodoro_style.island" }
                    ]
                },
                {
                    "key": "bar.moduleOptions.clock.showWeather",
                    "type": "toggle",
                    "label": "prefs.bar.clock_weather",
                    "description": "prefs.bar.clock_weather.desc",
                    "keywords": "clock weather symbol icon day name"
                }
            ]
        },
        {
            "id": "workspaces",
            "title": "prefs.bar.section.workspaces",
            "entries": [
                {
                    "key": "workspaces.shown",
                    "type": "slider",
                    "min": 1,
                    "max": 20,
                    "step": 1,
                    "label": "prefs.bar.ws_shown",
                    "description": "prefs.bar.ws_shown.desc",
                    "keywords": "workspaces count number visible desktops"
                },
                {
                    "key": "workspaces.numeralStyle",
                    "type": "custom",
                    "component": "NumeralCards",
                    "label": "prefs.bar.ws_numerals",
                    "description": "prefs.bar.ws_numerals.desc",
                    "keywords": "numerals kanji japanese roman arabic numbers workspaces"
                },
                {
                    "key": "workspaces.indicatorStyle",
                    "type": "custom",
                    "component": "IndicatorStyleChips",
                    "label": "prefs.bar.ws_indicator",
                    "description": "prefs.bar.ws_indicator.desc",
                    "keywords": "active workspace indicator highlight pill underline dot brush bracket retro ink"
                },
                {
                    "key": "workspaces.showNumbers",
                    "type": "toggle",
                    "label": "prefs.bar.ws_show_numbers",
                    "description": "prefs.bar.ws_show_numbers.desc",
                    "keywords": "workspace numbers labels index"
                },
                {
                    "key": "workspaces.alwaysShowNumbers",
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "workspaces.showNumbers",
                        "equals": true
                    },
                    "label": "prefs.bar.ws_always_numbers",
                    "description": "prefs.bar.ws_always_numbers.desc",
                    "keywords": "workspace numbers always empty"
                },
                {
                    "key": "workspaces.showAppIcons",
                    "type": "toggle",
                    "label": "prefs.bar.ws_app_icons",
                    "description": "prefs.bar.ws_app_icons.desc",
                    "keywords": "workspace app icons windows applications"
                },
                {
                    "key": "workspaces.dynamic",
                    "type": "toggle",
                    "label": "prefs.bar.ws_dynamic",
                    "description": "prefs.bar.ws_dynamic.desc",
                    "keywords": "dynamic workspaces occupied auto"
                }
            ]
        },
        {
            "id": "autohide",
            "title": "prefs.bar.section.autohide",
            "entries": [
                {
                    "key": "bar.pinnedOnStartup",
                    "type": "toggle",
                    "label": "prefs.bar.pinned",
                    "description": "prefs.bar.pinned.desc",
                    "keywords": "pin autohide hide show startup visible"
                },
                {
                    "key": "bar.hoverToReveal",
                    "type": "toggle",
                    "label": "prefs.bar.hover_reveal",
                    "description": "prefs.bar.hover_reveal.desc",
                    "keywords": "hover reveal mouse edge autohide"
                },
                {
                    "key": "bar.showPinButton",
                    "type": "toggle",
                    "label": "prefs.bar.pin_button",
                    "description": "prefs.bar.pin_button.desc",
                    "keywords": "pin button unpin"
                },
                {
                    "key": "bar.availableOnFullscreen",
                    "type": "toggle",
                    "label": "prefs.bar.fullscreen",
                    "description": "prefs.bar.fullscreen.desc",
                    "keywords": "fullscreen game video overlay"
                }
            ]
        }
    ]
};

// The former "classic" bar options: launcher icon, screens, expert knobs.
category.sections.push(...BarExtra.sections);
