.pragma library

// Effects (EasyEffects) as a list page (form "list"): the band shows the
// presets running on what you hear and on the microphone and turns the
// effects on and off (bypass); the row is the two preset lists. Live state
// (EasyEffectsService), no config keys. Entry format: see
// modules/settings/AGENTS.md.

var category = {
    "id": "effects",
    "icon": "waveform",
    "title": "prefs.cat.effects",
    "description": "prefs.cat.effects.desc",
    "keywords": "equalizer easyeffects bass audio effects presets noise microphone",
    "form": "list",
    "stage": "EffectsBand",
    // the cards hold a few presets each: the band takes more of the page
    "bandShare": 0.4,
    "hero": {
        "hint": "prefs.effects.hint"
    },
    "row": ["output", "input"],
    "sections": [
        {
            "id": "output",
            "title": "prefs.effects.output",
            "entries": [
                {
                    "id": "effects.output",
                    "type": "custom",
                    "component": "EffectPresets",
                    "output": true,
                    "resettable": false,
                    "label": "prefs.effects.output",
                    "description": "prefs.effects.output.desc",
                    "keywords": "presets output speakers headphones bass loudness equalizer"
                }
            ]
        },
        {
            "id": "input",
            "title": "prefs.effects.input",
            "entries": [
                {
                    "id": "effects.input",
                    "type": "custom",
                    "component": "EffectPresets",
                    "resettable": false,
                    "label": "prefs.effects.input",
                    "description": "prefs.effects.input.desc",
                    "keywords": "presets microphone noise gate voice"
                }
            ]
        }
    ]
};
