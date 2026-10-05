.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/specials.js (format: config/meta/Meta.js).

var description = "Special workspaces (Hyprland scratchpads): a name, icon, accent, a toggle bind and a send-window bind, and the apps each one opens. Global like the keybinds: presets never carry or change them.";

var COMBO = {
    "type": "object",
    "properties": {
        "modifiers": {
            "type": "array",
            "items": {
                "type": "string"
            }
        },
        "key": {
            "type": "string"
        }
    }
};

var keys = {
    "enabled": {
        "description": "Turn special workspaces on: their binds, window rules, app launching and preload (Hyprland only; hidden on other compositors)."
    },
    "launchTimeout": {
        "min": 1000,
        "max": 120000,
        "unit": "ms",
        "description": "How long a launched app may take to map its window; no second launch happens meanwhile."
    },
    "preloadDelay": {
        "min": 0,
        "max": 60000,
        "unit": "ms",
        "description": "Delay after login before preloading the apps of specials with preload on."
    },
    "workspaces": {
        "items": {
            "type": "object",
            "properties": {
                "id": {
                    "type": "string",
                    "description": "Stable id (never changes on rename)."
                },
                "name": {
                    "type": "string",
                    "description": "Display name; the Hyprland name (special:<name>) is derived from it safely."
                },
                "icon": {
                    "type": "string",
                    "description": "Icons glyph name (modules/theme/Icons.qml)."
                },
                "accent": {
                    "enum": Enums.SPECIAL_ACCENTS
                },
                "toggle": COMBO,
                "send": COMBO,
                "preload": {
                    "type": "boolean",
                    "description": "Launch its apps hidden in the special at login."
                },
                "apps": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": {
                                "type": "string",
                                "description": "Desktop entry id (e.g. org.telegram.desktop)."
                            },
                            "name": {
                                "type": "string"
                            },
                            "icon": {
                                "type": "string"
                            },
                            "match": {
                                "type": "string",
                                "description": "Window class (regex, case-insensitive, anchored)."
                            },
                            "command": {
                                "type": "string",
                                "description": "Launch command."
                            },
                            "ifRunning": {
                                "enum": Enums.SPECIAL_IF_RUNNING
                            },
                            "rule": {
                                "type": "boolean",
                                "description": "Window rule: windows of this app always open in the special."
                            }
                        },
                        "required": ["match"]
                    }
                }
            },
            "required": ["id", "name"]
        },
        "description": "The special workspaces [{id, name, icon, accent, toggle, send, preload, apps: [{id, name, icon, match, command, ifRunning: nothing | move, rule}]}]. Edit with `yozakura special ...`."
    }
};
