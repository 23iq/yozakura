.pragma library

// Sound as a list page (form "list"): the band is the output and the input
// as two big volume sliders (the output with a live meter); the row is the
// output devices, the input devices and the apps playing now with their
// own volume. Live system state (Audio / PipeWire), no config keys. Entry
// format: see modules/settings/AGENTS.md.

function list(id, title, description, component, extra, keywords) {
    var entry = {
        "id": "sound." + id,
        "type": "custom",
        "component": component,
        "resettable": false,
        "label": title,
        "description": description,
        "keywords": keywords
    };
    for (var k in extra)
        entry[k] = extra[k];
    return {
        "id": id,
        "title": title,
        "entries": [entry]
    };
}

var category = {
    "id": "sound",
    "icon": "speakerHigh",
    "title": "prefs.cat.sound",
    "description": "prefs.cat.sound.desc",
    "keywords": "sound audio volume mixer output input microphone speaker headphones apps",
    "form": "list",
    "stage": "SoundBand",
    "hero": {
        "hint": "prefs.sound.hint"
    },
    "row": ["outputs", "inputs", "apps"],
    "sections": [
        list("outputs", "prefs.sound.outputs", "prefs.sound.outputs.desc", "AudioDevices", {
            "output": true
        }, "output speakers headphones hdmi device default"),
        list("inputs", "prefs.sound.inputs", "prefs.sound.inputs.desc", "AudioDevices", {}, "input microphone mic headset device default"),
        list("apps", "prefs.sound.apps", "prefs.sound.apps.desc", "AppVolumes", {}, "apps applications mixer per app volume streams")
    ]
};
