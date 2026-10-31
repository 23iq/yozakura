.pragma library

// Look > Quick tune: the macro sliders (modules/settings/Macros.js). Each
// row moves several existing keys at once; the fine knobs stay below on the
// page. Spliced first into appearance.js.
// Entry format: see modules/settings/AGENTS.md.

function macro(id, keywords) {
    return {
        "id": "macro." + id,
        "type": "macro",
        "macro": id,
        "label": "prefs.macro." + id,
        "description": "prefs.macro." + id + ".desc",
        "keywords": keywords
    };
}

var sections = [
    {
        "id": "tune",
        "title": "prefs.macro.section",
        "entries": [
            macro("motion", "motion animation speed calm lively quick slow bouncy"),
            macro("density", "density spacing gaps compact airy roomy padding size"),
            macro("roundness", "roundness rounded corners radius square round"),
            macro("depth", "depth shadow shadows flat deep lighting 3d"),
            macro("glass", "glass transparency translucent frosted solid blur opacity")
        ]
    }
];
