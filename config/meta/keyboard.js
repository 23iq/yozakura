.pragma library
.import "Enums.js" as Enums

// Catalog metadata of config/defaults/keyboard.js (format: config/meta/Meta.js).

var description = "Keyboard layouts, the layout switch bind, extra XKB options and key repeat. Personal: presets never carry it.";

var keys = {
    "managed": {
        "description": "Yozakura manages the keyboard: renders these settings into the compositor config and applies them live. Off until the keyboard is changed in Yozakura; the compositor's own settings stay in effect until then."
    },
    "layouts": {
        "items": {
            "type": "object",
            "properties": {
                "layout": {
                    "type": "string",
                    "description": "XKB layout code, e.g. us, ru, de."
                },
                "variant": {
                    "type": "string",
                    "description": "XKB variant, e.g. intl; empty for none."
                }
            },
            "required": ["layout"]
        },
        "description": "Layouts in switch order [{layout, variant}]."
    },
    "switchBind": {
        "enum": Enums.KEYBOARD_SWITCH_BINDS,
        "description": "Key combination that cycles the layouts."
    },
    "options": {
        "items": {
            "type": "string"
        },
        "description": "Extra XKB options (e.g. ctrl:nocaps), besides the switch bind."
    },
    "repeatRate": {
        "min": 1,
        "max": 200,
        "unit": "/s",
        "description": "Key repeat rate."
    },
    "repeatDelay": {
        "min": 100,
        "max": 2000,
        "unit": "ms",
        "description": "Delay before a held key repeats."
    },
    "showIndicator": {
        "description": "Show the active layout (EN, RU, ...) in the bar."
    }
};
