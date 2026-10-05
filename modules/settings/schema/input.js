.pragma library
.import "../../keybinds/BindModel.js" as BindModel

// Input & Keybinds: every shell and compositor shortcut from binds.json,
// one card per BindModel group (KeybindGroupEditor), plus the toolbar
// (search, add, cheatsheet, conflicts). Edits apply live (binds.json ->
// compositor TOML -> yozd). Entry format: see modules/settings/AGENTS.md.

function groupSection(g) {
    return {
        "id": g.id,
        "entries": [
            {
                "id": "binds." + g.id,
                "type": "custom",
                "component": "KeybindGroupEditor",
                "group": g.id,
                "resettable": false,
                "label": g.title,
                "description": g.desc,
                "keywords": "keybinds shortcuts " + g.id
            }
        ]
    };
}

var category = {
    "id": "input",
    "icon": "keyboard",
    "title": "prefs.cat.input",
    "description": "prefs.cat.input.desc",
    "keywords": "keybinds shortcuts hotkeys keyboard bindings cheatsheet super record conflicts",
    "sections": [
        {
            "id": "overview",
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
    ].concat(BindModel.GROUPS.map(groupSection))
};
