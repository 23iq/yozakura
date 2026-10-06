.pragma library

// Popups > Menus: how the bar's popups and menus open (theme.popup).
// Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "menus",
    "icon": "list",
    "title": "prefs.cat.menus",
    "description": "prefs.cat.menus.desc",
    "keywords": "popup menu tooltip open animation tail gap",
    "sections": [
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
    },
    {
        "id": "popups",
        "title": "prefs.appearance.section.popups",
        "entries": [
            {
                "key": "theme.popup.entry",
                "type": "selector",
                "label": "prefs.appearance.popup_entry",
                "description": "prefs.appearance.popup_entry.desc",
                "keywords": "popup menu animation entry open fade scale slide morph unfold",
                "options": [
                    { "value": "fade-scale", "label": "prefs.appearance.popup_entry.fade_scale" },
                    { "value": "slide-from-anchor", "label": "prefs.appearance.popup_entry.slide" },
                    { "value": "morph-from-bar", "label": "prefs.appearance.popup_entry.morph" },
                    { "value": "unfold", "label": "prefs.appearance.popup_entry.unfold" }
                ]
            },
            {
                "key": "theme.popup.tail",
                "type": "toggle",
                "label": "prefs.appearance.popup_tail",
                "description": "prefs.appearance.popup_tail.desc",
                "keywords": "popup tail arrow pointer callout"
            },
            {
                "key": "theme.popup.gap",
                "type": "slider",
                "min": 0,
                "max": 32,
                "step": 1,
                "unit": "px",
                "label": "prefs.appearance.popup_gap",
                "description": "prefs.appearance.popup_gap.desc",
                "keywords": "popup gap distance margin offset bar"
            }
        ]
    }
    ]
};
