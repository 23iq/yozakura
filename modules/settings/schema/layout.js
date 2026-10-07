.pragma library

// Layout: where the launcher and dashboard open (notch, spotlight or side
// sheet) and which side the sheet uses, with a live edge preview of the
// screen. Hosts: modules/shell/hosts. Entry format: see modules/settings/AGENTS.md.

var HOSTS = [
    {
        "value": "notch",
        "label": "prefs.layout.host.notch",
        "icon": "dotsThree"
    },
    {
        "value": "spotlight",
        "label": "prefs.layout.host.spotlight",
        "icon": "magnifyingGlass"
    },
    {
        "value": "sheet",
        "label": "prefs.layout.host.sheet",
        "icon": "sidebarSimple"
    }
];

var category = {
    "id": "layout",
    "icon": "layout",
    "title": "prefs.cat.layout",
    "description": "prefs.cat.layout.desc",
    "keywords": "layout host spotlight sheet side panel notch launcher dashboard where open center edge preview bar dock parts",
    "sections": [
        {
            "id": "parts",
            "title": "prefs.layout.section.parts",
            "entries": [
                {
                    "id": "layout.builder",
                    "type": "custom",
                    "component": "LayoutBuilder",
                    // Edits the parts' edge/style/align keys too, but those
                    // live on the bar, notch and dock pages (one page per
                    // setting); notch.enabled is the builder's own
                    "keys": ["notch.enabled"],
                    "label": "prefs.layout.builder",
                    "description": "prefs.layout.builder.desc",
                    "keywords": "layout builder bar notch dock edge drag move hide show disable style align composable parts corner pills"
                }
            ]
        },
        {
            "id": "hosts",
            "title": "prefs.layout.section.hosts",
            "entries": [
                {
                    "key": "layout.launcher.host",
                    "type": "selector",
                    "options": HOSTS,
                    "preview": "LayoutPreview",
                    "label": "prefs.layout.launcher_host",
                    "description": "prefs.layout.launcher_host.desc",
                    "keywords": "launcher host spotlight sheet notch centered search"
                },
                {
                    "key": "layout.dashboard.host",
                    "type": "selector",
                    "options": HOSTS,
                    "label": "prefs.layout.dashboard_host",
                    "description": "prefs.layout.dashboard_host.desc",
                    "keywords": "dashboard host spotlight sheet notch side panel"
                },
                {
                    "key": "layout.sheet.side",
                    "type": "selector",
                    "options": [
                        {
                            "value": "auto",
                            "label": "common.auto"
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
                    "label": "prefs.layout.sheet_side",
                    "description": "prefs.layout.sheet_side.desc",
                    "keywords": "sheet side left right edge vertical bar"
                },
                {
                    "key": "layout.backdrop",
                    "type": "toggle",
                    "label": "prefs.layout.backdrop",
                    "description": "prefs.layout.backdrop.desc",
                    "keywords": "backdrop dim scrim blur background behind spotlight sheet overlay darken"
                },
                {
                    "key": "layout.cheatsheet.host",
                    "type": "selector",
                    "options": [
                        {
                            "value": "fullscreen",
                            "label": "prefs.layout.host.fullscreen",
                            "icon": "arrowsOut"
                        }
                    ].concat(HOSTS.slice(1)),
                    "label": "prefs.layout.cheatsheet_host",
                    "description": "prefs.layout.cheatsheet_host.desc",
                    "keywords": "keybinds cheatsheet shortcuts host fullscreen spotlight sheet"
                }
            ]
        }
    ]
};
