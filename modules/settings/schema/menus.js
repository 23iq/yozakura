.pragma library

// Popups > Menus: power menu and tools menu styles (notch, fullscreen,
// radial; modules/widgets/menus). Spliced into notifications.js.
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "menus",
        "title": "prefs.menus.section",
        "entries": [
            {
                "key": "layout.powermenu.style",
                "type": "selector",
                "options": [
                    {
                        "value": "notch",
                        "label": "prefs.menus.style.notch",
                        "icon": "dotsThree"
                    },
                    {
                        "value": "fullscreen",
                        "label": "prefs.menus.style.fullscreen",
                        "icon": "arrowsOut"
                    },
                    {
                        "value": "radial",
                        "label": "prefs.menus.style.radial",
                        "icon": "circleNotch"
                    }
                ],
                "label": "prefs.menus.powermenu_style",
                "description": "prefs.menus.powermenu_style.desc",
                "keywords": "power menu shutdown reboot logout style radial fullscreen notch hold confirm"
            },
            {
                "key": "layout.tools.style",
                "type": "selector",
                "options": [
                    {
                        "value": "notch",
                        "label": "prefs.menus.style.notch",
                        "icon": "dotsThree"
                    },
                    {
                        "value": "radial",
                        "label": "prefs.menus.style.radial",
                        "icon": "circleNotch"
                    }
                ],
                "label": "prefs.menus.tools_style",
                "description": "prefs.menus.tools_style.desc",
                "keywords": "tools menu screenshot record color picker ocr style radial notch cursor"
            }
        ]
    }
];
