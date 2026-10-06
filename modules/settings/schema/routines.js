.pragma library

// Routines: deterministic step lists (bind actions, built-in tools,
// delays) stored by the backend (svc/routines, routines.json), run from a
// keybind, the launcher, an AI automation or the AI. The editor talks to
// the backend directly (RoutinesService), not to a config key.
// Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "routines",
    "icon": "lightning",
    "title": "prefs.cat.routines",
    "description": "prefs.cat.routines.desc",
    "keywords": "routine routines macro automation scene steps shortcut one key several actions workflow",
    "sections": [
        {
            "id": "list",
            "title": "prefs.routines.section.list",
            "entries": [
                {
                    "id": "routines.list",
                    "type": "custom",
                    "component": "RoutinesEditor",
                    "resettable": false,
                    "label": "prefs.routines.list",
                    "description": "prefs.routines.list.desc",
                    "keywords": "add new routine template focus night meeting music steps action tool delay test run keybind launcher"
                }
            ]
        }
    ]
};
