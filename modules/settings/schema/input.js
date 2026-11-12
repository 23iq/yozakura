.pragma library

// Shortcuts: every shell and compositor shortcut from binds.json as a list
// page (form "list"): the band is a keyboard drawn from keycaps with the
// opened shortcut's keys lit; the row is the list itself (grouped, one
// compact row per bind, a click opens it to record keys or change the
// action) and the toolbar beside it (search, add, conflicts, cheatsheet).
// Edits apply live (binds.json -> compositor TOML -> yozd). Entry format:
// see modules/settings/AGENTS.md.

var category = {
    "id": "input",
    "icon": "keyboard",
    "title": "prefs.cat.input",
    "description": "prefs.cat.input.desc",
    "keywords": "keybinds shortcuts hotkeys keyboard bindings cheatsheet super record conflicts",
    "form": "list",
    "stage": "KeysBand",
    "hero": {
        "hint": "prefs.keys.hint"
    },
    "row": [
        {
            "id": "shortcuts",
            "weight": 2
        },
        "overview"
    ],
    "sections": [
        {
            "id": "shortcuts",
            "title": "prefs.keys.section.shortcuts",
            "entries": [
                {
                    "id": "binds.list",
                    "type": "custom",
                    "component": "ShortcutList",
                    "resettable": false,
                    "label": "prefs.keys.section.shortcuts",
                    "description": "prefs.keys.list.desc",
                    "keywords": "keybinds shortcuts list groups workspaces windows apps launcher media screenshot record keys"
                }
            ]
        },
        {
            "id": "overview",
            "title": "prefs.keys.section.find",
            "entries": [
                {
                    "id": "binds.overview",
                    "type": "custom",
                    "component": "KeybindsOverview",
                    "resettable": false,
                    "label": "binds.overview",
                    "description": "binds.overview.desc",
                    "keywords": "search add custom shortcut command cheatsheet conflicts reload"
                }
            ]
        }
    ]
};
