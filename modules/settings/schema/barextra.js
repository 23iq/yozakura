.pragma library

// Bar extras, spliced into bar.js: the launcher button icon, the monitors
// of the single bar, the Firefox media player and the expert knobs of the
// auto-hide and the frame. Entry format: see modules/settings/AGENTS.md.

// The single legacy bar (no multi-panel layout): panels have their own.
var SINGLE_BAR = {
    "key": "bar.panels",
    "empty": true
};

var sections = [
    {
        "id": "launcher",
        "title": "prefs.bar.section.launcher",
        "entries": [
            {
                "key": "bar.launcherIcon",
                "type": "path",
                "pathKind": "file",
                "placeholder": "prefs.bar.launcher_icon.placeholder",
                "label": "prefs.bar.launcher_icon",
                "description": "prefs.bar.launcher_icon.desc",
                "keywords": "launcher icon logo symbol image path start menu button"
            },
            {
                "key": "bar.launcherIconSize",
                "type": "slider",
                "min": 8,
                "max": 64,
                "step": 1,
                "unit": "px",
                "label": "prefs.bar.launcher_icon_size",
                "description": "prefs.bar.launcher_icon_size.desc",
                "keywords": "launcher icon size logo big small"
            },
            {
                "key": "bar.launcherIconTint",
                "type": "toggle",
                "label": "prefs.bar.launcher_icon_tint",
                "description": "prefs.bar.launcher_icon_tint.desc",
                "keywords": "launcher icon tint color palette recolor"
            }
        ]
    },
    {
        "id": "screens",
        "title": "prefs.bar.section.screens",
        "entries": [
            {
                "key": "bar.screenList",
                "type": "screens",
                "visibleWhen": SINGLE_BAR,
                "label": "prefs.bar.screens",
                "description": "prefs.bar.screens.desc",
                "keywords": "bar monitor screen display multi-monitor where"
            },
            {
                "key": "bar.enableFirefoxPlayer",
                "type": "toggle",
                "label": "prefs.bar.firefox_player",
                "description": "prefs.bar.firefox_player.desc",
                "keywords": "firefox browser media player mpris music video youtube"
            }
        ]
    },
    {
        "id": "expert",
        "title": "prefs.bar.section.expert",
        "entries": [
            {
                "key": "bar.hoverRegionHeight",
                "type": "slider",
                "min": 0,
                "max": 40,
                "step": 1,
                "unit": "px",
                "advanced": true,
                "visibleWhen": {
                    "key": "bar.hoverToReveal",
                    "equals": true
                },
                "label": "prefs.bar.hover_region",
                "description": "prefs.bar.hover_region.desc",
                "keywords": "bar hover region trigger strip area reveal autohide"
            },
            {
                "key": "bar.keepBarShadow",
                "type": "toggle",
                "advanced": true,
                "visibleWhen": {
                    "all": [{
                            "key": "bar.frameEnabled",
                            "equals": true
                        }, {
                            "key": "bar.containBar",
                            "equals": true
                        }]
                },
                "label": "prefs.bar.keep_shadow",
                "description": "prefs.bar.keep_shadow.desc",
                "keywords": "frame contain bar shadow keep"
            },
            {
                "key": "bar.keepBarBorder",
                "type": "toggle",
                "advanced": true,
                "visibleWhen": {
                    "all": [{
                            "key": "bar.frameEnabled",
                            "equals": true
                        }, {
                            "key": "bar.containBar",
                            "equals": true
                        }]
                },
                "label": "prefs.bar.keep_border",
                "description": "prefs.bar.keep_border.desc",
                "keywords": "frame contain bar border outline keep"
            }
        ]
    }
];
