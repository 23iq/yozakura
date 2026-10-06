.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/notifications.js (format: config/meta/Meta.js).

var description = "Notification popups: presentation (notch-born toasts or corner toasts, auto = by the preset's bar style), corner, screens, timeout, stacking, grouping, history size, sound, per-app rules and Do Not Disturb (manual + schedule).";

var keys = {
    "presentation": {
        "enum": Enums.NOTIFICATION_PRESENTATIONS
    },
    "position": {
        "enum": Enums.NOTIFICATION_POSITIONS
    },
    "screens": {
        "items": {
            "type": "string"
        },
        "uniqueItems": true,
        "description": "Monitor names that show notifications; empty = every screen."
    },
    "timeout": {
        "min": 0,
        "max": 120000,
        "unit": "ms"
    },
    "historySize": {
        "min": 0,
        "max": 1000
    },
    "sound.file": {
        "format": "path"
    },
    "rules": {
        "items": {
            "type": "object",
            "properties": {
                "app": {
                    "type": "string",
                    "description": "App name or desktop id, case-insensitive; * is a wildcard."
                },
                "action": {
                    "enum": Enums.NOTIFICATION_RULE_ACTIONS
                }
            },
            "required": ["app", "action"]
        },
        "description": "Per-app rules [{app, action: mute | priority | alwaysShow | soundOff}]; every matching rule applies."
    },
    "dnd.schedule.from": {
        "pattern": "^([01]?\\d|2[0-3]):[0-5]\\d$"
    },
    "dnd.schedule.to": {
        "pattern": "^([01]?\\d|2[0-3]):[0-5]\\d$"
    },
    "dnd.schedule.days": {
        "description": "Days (0 = Sunday) a Do Not Disturb window starts on."
    },
    "notchStyle": {
        "enum": ["card", "pill"],
        "description": "Look of notch-born toasts: a full card or a compact pill."
    }
};
