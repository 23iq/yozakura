.pragma library
.import "barextra.js" as BarExtra
.import "barsentence.js" as BarSentence

// Bar: its look and edge, modules, clock, workspaces and when it shows,
// over a live stage of the bar (stages/BarStage.qml). The reference page of
// the window (modules/settings/AGENTS.md, CONVERTING A PAGE): one control
// per setting, picture cards for looks, expert knobs `advanced` (out of
// the window, still in `yozakura config`). Entry format: see AGENTS.md.

// The shared pin (bar.pinnedOnStartup, the pin button) only drives panels
// whose auto-hide is "auto" (BarContent.qml; a missing value is auto, the
// legacy true / false are always / never). No panels = the single bar (auto).
var PIN_APPLIES = {
    "any": [
        { "key": "bar.panels", "empty": true },
        { "key": "bar.panels", "some": { "field": "autohide", "notIn": ["always", "never", true, false] } }
    ]
};

var category = {
    "id": "bar",
    "icon": "squaresFour",
    "title": "prefs.cat.bar",
    "description": "prefs.cat.bar.desc",
    "keywords": "bar panel taskbar islands top modules widgets",
    "stage": "BarStage",
    // Beside the stage: the bars (left), when the bar shows (right).
    "hero": {
        "hint": "prefs.bar.hero_hint"
    },
    // One row of cards under the stage.
    "row": [{ "id": "shape", "weight": 1.5 }, { "id": "size", "weight": 0.8 }, { "id": "layout", "weight": 1.25 }],
    "sections": [
        {
            "id": "panels",
            "title": "prefs.bar.section.panels",
            "entries": [
                {
                    "id": "bar.panels.list",
                    "type": "custom",
                    "component": "PanelList",
                    "keys": ["bar.panels"],
                    // the list of bars beside the stage; the selected bar's
                    // fields are bar.panels.editor's (one part each)
                    "part": true,
                    "resettable": false,
                    "label": "prefs.bar.panels",
                    "description": "prefs.bar.panels.desc",
                    "keywords": "bars panels add bar second bar"
                },
                {
                    "id": "bar.panels.editor",
                    "type": "custom",
                    "component": "PanelsEditor",
                    "keys": ["bar.panels"],
                    // Several bars (from a preset or `yozakura config`): this
                    // editor replaces the single bar's style, edge and modules.
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": false
                    },
                    "label": "prefs.bar.panels.selected",
                    "description": "prefs.bar.panels.desc",
                    "keywords": "panels layout bars edge style dock menubar taskbar rail corners statusline ribbon two bars multi monitor modules"
                }
            ]
        },
        {
            "id": "shape",
            "title": "prefs.bar.style",
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
                    "id": "bar.panels.style",
                    "type": "custom",
                    "component": "PanelShapeCards",
                    "keys": ["bar.panels"],
                    "part": true,
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": false
                    },
                    "label": "prefs.bar.style",
                    "description": "prefs.bar.style.desc",
                    "keywords": "panel bar shape style"
                }
            ]
        },
        {
            "id": "size",
            "title": "prefs.bar.size",
            "entries": [
                {
                    "key": "bar.compact",
                    "type": "custom",
                    "component": "BarSizeCards",
                    "label": "prefs.bar.compact",
                    "description": "prefs.bar.compact.desc",
                    "keywords": "compact dense slim thin small height size"
                }
            ]
        },
        {
            "id": "style",
            "title": "prefs.bar.section.edge_frame",
            "entries": [
                {
                    "key": "bar.position",
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": true
                    },
                    "type": "selector",
                    "display": "cards",
                    "thumb": "BarEdgeThumb",
                    "options": [
                        { "value": "top", "label": "common.top" },
                        { "value": "bottom", "label": "common.bottom" },
                        { "value": "left", "label": "common.left" },
                        { "value": "right", "label": "common.right" }
                    ],
                    "label": "prefs.label.bar_edge",
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
                    "advanced": true,
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
                    // built once the page shows (SettingRow `lazy`)
                    "lazy": true,
                    "keys": ["bar.layout.left", "bar.layout.right", "bar.layout.drawer"],
                    "label": "prefs.label.bar_modules",
                    "description": "prefs.bar.layout.desc",
                    "keywords": "modules widgets order arrange drag drop drawer left right add remove launcher clock battery tray"
                },
                {
                    "id": "bar.panels.modules",
                    "type": "custom",
                    "component": "PanelModulesCard",
                    "lazy": true,
                    "keys": ["bar.panels"],
                    "part": true,
                    "visibleWhen": {
                        "key": "bar.panels",
                        "empty": false
                    },
                    "label": "prefs.label.bar_modules",
                    "description": "prefs.bar.layout.desc",
                    "keywords": "panel modules widgets order arrange drag drop"
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
                    "display": "cards",
                    "thumb": "ClockFaceThumb",
                    "label": "prefs.bar.clock_face",
                    "description": "prefs.bar.clock_face.desc",
                    "keywords": "clock face style digital stacked dot matrix led lcd seven segment kanji japanese",
                    "options": [
                        { "value": "digital", "label": "prefs.bar.clock_face.digital" },
                        { "value": "stacked", "label": "prefs.bar.clock_face.stacked" },
                        { "value": "dotMatrix", "label": "prefs.bar.clock_face.dotMatrix" },
                        { "value": "kanji", "label": "prefs.bar.clock_face.kanji" },
                        { "value": "segment", "label": "prefs.bar.clock_face.segment" }
                    ]
                },
                {
                    "key": "bar.moduleOptions.clock.pomodoroStyle",
                    "advanced": true,
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
                    "key": "bar.moduleOptions.clock.panelStyle",
                    "type": "selector",
                    "display": "cards",
                    "thumb": "ClockPanelThumb",
                    "label": "prefs.bar.clock_panel",
                    "description": "prefs.bar.clock_panel.desc",
                    "keywords": "clock popup panel calendar pomodoro world clocks weather column wide bento grid layout",
                    "options": [
                        { "value": "column", "label": "prefs.bar.clock_panel.column" },
                        { "value": "wide", "label": "prefs.bar.clock_panel.wide" },
                        { "value": "bento", "label": "prefs.bar.clock_panel.bento" }
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
            "id": "media",
            "title": "prefs.bar.section.media",
            "advanced": true,
            "entries": [
                {
                    "key": "bar.moduleOptions.media.showTitle",
                    "type": "toggle",
                    "label": "prefs.bar.media_title",
                    "description": "prefs.bar.media_title.desc",
                    "keywords": "media music player title song track module"
                },
                {
                    "key": "bar.moduleOptions.media.visualizer",
                    "type": "toggle",
                    "label": "prefs.bar.media_visualizer",
                    "description": "prefs.bar.media_visualizer.desc",
                    "keywords": "media music visualizer cava bars audio module"
                }
            ]
        },
        {
            "id": "workspaces",
            "title": "prefs.bar.section.workspaces",
            "entries": [
                {
                    "key": "workspaces.shown",
                    "type": "number",
                    "min": 1,
                    "max": 20,
                    "step": 1,
                    "label": "prefs.bar.ws_shown",
                    "description": "prefs.bar.ws_shown.desc",
                    "keywords": "workspaces count number visible desktops"
                },
                {
                    "key": "workspaces.indicatorStyle",
                    "type": "custom",
                    "component": "IndicatorCards",
                    "label": "prefs.bar.ws_indicator",
                    "description": "prefs.bar.ws_indicator.desc",
                    "keywords": "active workspace indicator highlight pill underline dot brush bracket retro ink branch blossom"
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
                    "key": "workspaces.branchBlossom",
                    "advanced": true,
                    "type": "custom",
                    "component": "BranchBlossomChips",
                    "visibleWhen": {
                        "key": "workspaces.indicatorStyle",
                        "equals": "branch"
                    },
                    "label": "prefs.bar.ws_branch_blossom",
                    "description": "prefs.bar.ws_branch_blossom.desc",
                    "keywords": "branch blossom flower petal sakura plum round leaf shape workspaces"
                },
                {
                    "key": "workspaces.branchColor",
                    "advanced": true,
                    "type": "custom",
                    "component": "ColorRoleSwatches",
                    "options": [
                        { "value": "primary", "label": "prefs.glass.role.primary" },
                        { "value": "secondary", "label": "prefs.glass.role.secondary" },
                        { "value": "tertiary", "label": "prefs.glass.role.tertiary" }
                    ],
                    "visibleWhen": {
                        "key": "workspaces.indicatorStyle",
                        "equals": "branch"
                    },
                    "label": "prefs.bar.ws_branch_color",
                    "description": "prefs.bar.ws_branch_color.desc",
                    "keywords": "branch blossom colour color palette role accent workspaces"
                },
                {
                    "key": "workspaces.branchPetalFall",
                    "advanced": true,
                    "type": "toggle",
                    "visibleWhen": {
                        "key": "workspaces.indicatorStyle",
                        "equals": "branch"
                    },
                    "label": "prefs.label.branch_petals",
                    "description": "prefs.bar.ws_branch_fall.desc",
                    "keywords": "branch petal fall animation window close workspaces"
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
                    "advanced": true,
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
                    "enabledWhen": PIN_APPLIES,
                    "reason": "prefs.bar.pin.reason",
                    "label": "prefs.bar.pinned",
                    "description": "prefs.bar.pinned.desc",
                    "keywords": "pin autohide hide show startup visible"
                },
                {
                    "key": "bar.showPinButton",
                    "type": "toggle",
                    "enabledWhen": PIN_APPLIES,
                    "reason": "prefs.bar.pin.reason",
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

// The sentence module, after the media one
category.sections.splice(category.sections.findIndex(function (s) {
    return s.id === "media";
}) + 1, 0, ...BarSentence.sections);

// The former "classic" bar options: launcher icon, screens, expert knobs.
category.sections.push(...BarExtra.sections);
