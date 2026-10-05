.pragma library

// Special workspaces (Hyprland scratchpads): the list editor (templates,
// name, icon, accent, toggle + send binds, apps, preload) and the runtime
// options. Global like the keybinds: presets never carry them. Logic:
// modules/specials/. Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "specials",
    "icon": "cube",
    "title": "prefs.cat.specials",
    "description": "prefs.cat.specials.desc",
    "keywords": "special workspaces scratchpad scratchpads hidden workspace telegram discord chat music dev notes toggle send window apps preload",
    "sections": [
        {
            "id": "list",
            "title": "prefs.specials.section.list",
            "entries": [
                {
                    "key": "specials.workspaces",
                    "type": "custom",
                    "component": "SpecialsEditor",
                    "label": "prefs.specials.list",
                    "description": "prefs.specials.list.desc",
                    "keywords": "add special workspace template chat music dev notes custom bind toggle send window apps class command rule"
                }
            ]
        },
        {
            "id": "behaviour",
            "title": "prefs.specials.section.behaviour",
            "entries": [
                {
                    "key": "specials.enabled",
                    "type": "toggle",
                    "label": "prefs.specials.enabled",
                    "description": "prefs.specials.enabled.desc",
                    "keywords": "on off disable binds rules launch"
                },
                {
                    "key": "specials.launchTimeout",
                    "type": "slider",
                    "label": "prefs.specials.launch_timeout",
                    "description": "prefs.specials.launch_timeout.desc",
                    "keywords": "launch wait slow app double",
                    "min": 2000,
                    "max": 60000,
                    "step": 1000,
                    "unit": "ms",
                    "visibleWhen": {
                        "key": "specials.enabled",
                        "equals": true
                    }
                },
                {
                    "key": "specials.preloadDelay",
                    "type": "slider",
                    "label": "prefs.specials.preload_delay",
                    "description": "prefs.specials.preload_delay.desc",
                    "keywords": "login startup preload delay",
                    "min": 0,
                    "max": 30000,
                    "step": 500,
                    "unit": "ms",
                    "visibleWhen": {
                        "key": "specials.enabled",
                        "equals": true
                    }
                }
            ]
        }
    ]
};
