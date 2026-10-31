.pragma library

// Appearance > Lighting: one light source for the shell's shadows and lit
// edges (theme.lighting, modules/theme/Lighting.qml) and the cursor
// lantern. Spliced into appearance.js after "effects".
// Entry format: see modules/settings/AGENTS.md.

var sections = [
    {
        "id": "lighting",
        "title": "prefs.lighting.section",
        "entries": [
            {
                "key": "theme.lighting.mode",
                "type": "selector",
                "preview": "LightingPreview",
                "label": "prefs.lighting.mode",
                "description": "prefs.lighting.mode.desc",
                "options": [
                    {
                        "value": "off",
                        "label": "prefs.lighting.mode.off"
                    },
                    {
                        "value": "fixed",
                        "label": "prefs.lighting.mode.fixed"
                    },
                    {
                        "value": "sun",
                        "label": "prefs.lighting.mode.sun"
                    }
                ],
                "keywords": "lighting light sun shadow direction time of day dawn dusk noon"
            },
            {
                "key": "theme.lighting.angle",
                "type": "slider",
                "min": -180,
                "max": 180,
                "step": 5,
                "unit": "deg",
                "visibleWhen": {
                    "key": "theme.lighting.mode",
                    "equals": "fixed"
                },
                "label": "prefs.lighting.angle",
                "description": "prefs.lighting.angle.desc",
                "keywords": "light angle direction shadow side"
            },
            {
                "key": "theme.lighting.lantern",
                "type": "selector",
                "label": "prefs.lighting.lantern",
                "description": "prefs.lighting.lantern.desc",
                "options": [
                    {
                        "value": "off",
                        "label": "prefs.common.off"
                    },
                    {
                        "value": "night",
                        "label": "prefs.lighting.lantern.night"
                    },
                    {
                        "value": "always",
                        "label": "prefs.lighting.lantern.always"
                    }
                ],
                "keywords": "lantern cursor pointer glow light night hover"
            }
        ]
    }
];
