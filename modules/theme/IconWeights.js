.pragma library

// Phosphor icon font weights (MIT, assets/fonts/phosphor). Every weight
// shares the same codepoints, so switching weight only switches the family
// (Icons.font). FontRegistry loads `files()`.
//
// "duotone" is deliberately not offered: a duotone glyph is two stacked
// layers (codepoint + codepoint+1 at 20% opacity), and icons are single
// Text items all over the shell; supporting it would mean touching every
// icon site for one style.
var ROOT = "assets/fonts/phosphor/";
var DEFAULT_WEIGHT = "bold";

var WEIGHTS = [
    {"weight": "regular", "family": "Phosphor", "file": "Phosphor-Regular.ttf"},
    {"weight": "bold", "family": "Phosphor-Bold", "file": "Phosphor-Bold.ttf"},
    {"weight": "fill", "family": "Phosphor-Fill", "file": "Phosphor-Fill.ttf"}
];

function weights() {
    return WEIGHTS.map(function (w) {
        return w.weight;
    });
}

// Font family of a weight; an unknown or corrupt value falls back to bold.
function family(weight) {
    for (var i = 0; i < WEIGHTS.length; i++) {
        if (WEIGHTS[i].weight === weight)
            return WEIGHTS[i].family;
    }
    return family(DEFAULT_WEIGHT);
}

function files() {
    return WEIGHTS.map(function (w) {
        return ROOT + w.file;
    });
}
