.pragma library

// Catalog metadata of config/defaults/displays.js (format: config/meta/Meta.js).

var description = "Saved monitor layout (resolution, refresh rate, position, scale, rotation, variable refresh rate). Machine specific: presets never carry it. Edit it in Settings > Displays, which applies changes with an automatic revert.";

var keys = {
    "monitors": {
        "items": {
            "type": "object",
            "properties": {
                "id": {
                    "type": "string",
                    "description": "Stable monitor id (make, model, serial); matches the entry when the connector changes."
                },
                "name": {
                    "type": "string",
                    "description": "Connector name, e.g. DP-1."
                },
                "enabled": {
                    "type": "boolean"
                },
                "width": {
                    "type": "integer",
                    "minimum": 0
                },
                "height": {
                    "type": "integer",
                    "minimum": 0
                },
                "refresh": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Refresh rate in Hz (0 = preferred)."
                },
                "x": {
                    "type": "integer"
                },
                "y": {
                    "type": "integer"
                },
                "autoPosition": {
                    "type": "boolean",
                    "description": "Let the compositor place the monitor."
                },
                "scale": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Scale factor (0 = automatic)."
                },
                "transform": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 7,
                    "description": "Rotation: 0 normal, 1 90, 2 180, 3 270, 4-7 flipped."
                },
                "vrr": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 2,
                    "description": "Variable refresh rate: 0 off, 1 on, 2 fullscreen only."
                }
            },
            "required": ["name"]
        },
        "description": "The monitors [{id, name, enabled, width, height, refresh, x, y, autoPosition, scale, transform, vrr}]."
    }
};
