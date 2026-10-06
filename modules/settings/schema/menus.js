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
