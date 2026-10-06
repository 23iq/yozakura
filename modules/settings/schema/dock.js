.pragma library

// Dock: the app dock (standalone, floating or integrated into the bar), its
// size, auto-hide, buttons and effects. Entry format: see
// modules/settings/AGENTS.md.

// Shown while the dock is on.
var ON = {
    "key": "dock.enabled",
    "equals": true
};

// Shown while the dock is its own window (not integrated into the bar).
var STANDALONE = {
    "all": [ON, {
            "key": "dock.theme",
            "notEquals": "integrated"
        }]
};

var category = {
    "id": "dock",
    "icon": "dock",
    "title": "prefs.cat.dock",
    "description": "prefs.cat.dock.desc",
    "keywords": "dock taskbar apps favorites pinned running launcher",
    "sections": [
        {
            "id": "dock",
            "title": "prefs.dock.section.dock",
            "entries": [
                {
                    "key": "dock.enabled",
                    "type": "toggle",
                    "label": "prefs.dock.enabled",
                    "description": "prefs.dock.enabled.desc",
                    "keywords": "dock enable show hide on off"
                },
                {
                    "key": "dock.theme",
                    "type": "selector",
                    "visibleWhen": ON,
                    "options": [
                        {
                            "value": "default",
                            "label": "common.default"
                        },
                        {
                            "value": "floating",
                            "label": "shell.dock.floating"
                        },
                        {
                            "value": "integrated",
                            "label": "shell.dock.integrated"
                        }
                    ],
                    "label": "prefs.dock.theme",
                    "description": "prefs.dock.theme.desc",
                    "keywords": "dock style theme floating integrated bar inside"
                },
                {
                    "key": "dock.position",
                    "type": "selector",
                    "visibleWhen": STANDALONE,
                    "options": [
                        {
                            "value": "top",
                            "label": "common.top",
                            "icon": "arrowUp"
                        },
                        {
                            "value": "bottom",
                            "label": "common.bottom",
                            "icon": "arrowDown"
                        },
                        {
                            "value": "left",
                            "label": "common.left",
                            "icon": "arrowLeft"
                        },
                        {
                            "value": "right",
                            "label": "common.right",
                            "icon": "arrowRight"
                        }
                    ],
                    "label": "prefs.dock.position",
                    "description": "prefs.dock.position.desc",
                    "keywords": "dock position edge top bottom left right vertical"
                },
                {
                    "key": "dock.screenList",
                    "type": "screens",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.screens",
                    "description": "prefs.dock.screens.desc",
                    "keywords": "dock monitor screen display multi-monitor where"
                }
            ]
        },
        {
            "id": "size",
            "title": "prefs.dock.section.size",
            "entries": [
                {
                    "key": "dock.iconSize",
                    "type": "slider",
                    "min": 12,
                    "max": 96,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.icon_size",
                    "description": "prefs.dock.icon_size.desc",
                    "keywords": "dock icon size apps big small"
                },
                {
                    "key": "dock.height",
                    "type": "slider",
                    "min": 24,
                    "max": 128,
                    "step": 1,
                    "unit": "px",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.height",
                    "description": "prefs.dock.height.desc",
                    "keywords": "dock height thickness size width"
                },
                {
                    "key": "dock.spacing",
                    "type": "slider",
                    "min": 0,
                    "max": 32,
                    "step": 1,
                    "unit": "px",
                    "advanced": true,
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.spacing",
                    "description": "prefs.dock.spacing.desc",
                    "keywords": "dock spacing gap between icons"
                },
                {
                    "key": "dock.margin",
                    "type": "slider",
                    "min": 0,
                    "max": 64,
                    "step": 1,
                    "unit": "px",
                    "advanced": true,
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.margin",
                    "description": "prefs.dock.margin.desc",
                    "keywords": "dock margin distance edge offset"
                }
            ]
        },
        {
            "id": "autohide",
            "title": "prefs.dock.section.autohide",
            "entries": [
                {
                    "key": "dock.pinnedOnStartup",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.pinned",
                    "description": "prefs.dock.pinned.desc",
                    "keywords": "dock pin autohide hide show startup always visible"
                },
                {
                    "key": "dock.hoverToReveal",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.hover_reveal",
                    "description": "prefs.dock.hover_reveal.desc",
                    "keywords": "dock hover reveal mouse edge autohide"
                },
                {
                    "key": "dock.keepHidden",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.keep_hidden",
                    "description": "prefs.dock.keep_hidden.desc",
                    "keywords": "dock keep hidden autohide windows empty desktop"
                },
                {
                    "key": "dock.availableOnFullscreen",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.fullscreen",
                    "description": "prefs.dock.fullscreen.desc",
                    "keywords": "dock fullscreen game video overlay"
                },
                {
                    "key": "dock.hoverRegionHeight",
                    "type": "slider",
                    "min": 0,
                    "max": 64,
                    "step": 1,
                    "unit": "px",
                    "advanced": true,
                    "visibleWhen": {
                        "all": [STANDALONE, {
                                "key": "dock.hoverToReveal",
                                "equals": true
                            }]
                    },
                    "label": "prefs.dock.hover_region",
                    "description": "prefs.dock.hover_region.desc",
                    "keywords": "dock hover region trigger strip area reveal"
                }
            ]
        },
        {
            "id": "content",
            "title": "prefs.dock.section.content",
            "entries": [
                {
                    "key": "dock.showRunningIndicators",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.running",
                    "description": "prefs.dock.running.desc",
                    "keywords": "dock running indicators dots open apps"
                },
                {
                    "key": "dock.indicator",
                    "type": "selector",
                    "visibleWhen": {
                        "all": [ON, {
                                "key": "dock.showRunningIndicators",
                                "equals": true
                            }]
                    },
                    "options": [
                        {
                            "value": "dot",
                            "label": "prefs.dock.indicator.dot"
                        },
                        {
                            "value": "line",
                            "label": "prefs.dock.indicator.line"
                        },
                        {
                            "value": "glow",
                            "label": "prefs.dock.indicator.glow"
                        },
                        {
                            "value": "brush",
                            "label": "prefs.dock.indicator.brush"
                        }
                    ],
                    "label": "prefs.dock.indicator",
                    "description": "prefs.dock.indicator.desc",
                    "keywords": "dock indicator running dot line glow brush style"
                },
                {
                    "key": "dock.showPinButton",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.pin_button",
                    "description": "prefs.dock.pin_button.desc",
                    "keywords": "dock pin button keep visible"
                },
                {
                    "key": "dock.showOverviewButton",
                    "type": "toggle",
                    "visibleWhen": STANDALONE,
                    "label": "prefs.dock.overview_button",
                    "description": "prefs.dock.overview_button.desc",
                    "keywords": "dock overview button workspaces mission control"
                },
                {
                    "key": "dock.ignoredAppRegexes",
                    "type": "list",
                    "itemType": "text",
                    "advanced": true,
                    "visibleWhen": ON,
                    "placeholder": "prefs.dock.ignored.placeholder",
                    "addLabel": "prefs.dock.ignored.add",
                    "emptyLabel": "prefs.dock.ignored.empty",
                    "label": "prefs.dock.ignored",
                    "description": "prefs.dock.ignored.desc",
                    "keywords": "dock ignore hide apps regex filter exclude app id class"
                }
            ]
        },
        {
            "id": "effects",
            "title": "prefs.dock.section.effects",
            "entries": [
                {
                    "key": "dock.magnification",
                    "type": "toggle",
                    "label": "prefs.dock.magnification",
                    "description": "prefs.dock.magnification.desc",
                    "keywords": "dock magnification zoom magnify icons hover macos"
                },
                {
                    "key": "dock.magnificationScale",
                    "type": "slider",
                    "min": 1,
                    "max": 2.5,
                    "step": 0.1,
                    "unit": "×",
                    "visibleWhen": {
                        "key": "dock.magnification",
                        "equals": true
                    },
                    "label": "prefs.dock.magnification_scale",
                    "description": "prefs.dock.magnification_scale.desc",
                    "keywords": "dock magnification scale zoom amount size"
                },
                {
                    "key": "dock.launchBounce",
                    "type": "toggle",
                    "label": "prefs.dock.launch_bounce",
                    "description": "prefs.dock.launch_bounce.desc",
                    "keywords": "dock launch bounce animation opening app"
                }
            ]
        }
    ]
};
