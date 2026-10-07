.pragma library

// Options of the wallpapers tab's colour-scheme dropdown: the matugen schemes
// followed by the named colour presets. A value is "matugen:<id>" or
// "preset:<name>" so both kinds share one list.

var MATUGEN = ["scheme-content", "scheme-expressive", "scheme-fidelity", "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral", "scheme-rainbow", "scheme-tonal-spot"];

// tr(key) translates; the label key is wallpapers.scheme_<id without "scheme-", dashes as underscores>.
function options(presets, tr) {
    var list = [];
    for (var i = 0; i < MATUGEN.length; i++)
        list.push({ "value": "matugen:" + MATUGEN[i], "text": tr("wallpapers." + MATUGEN[i].replace("scheme-", "scheme_").replace(/-/g, "_")) });
    var p = presets || [];
    for (var j = 0; j < p.length; j++)
        list.push({ "value": "preset:" + p[j], "text": p[j] });
    return list;
}

// The active option: a colour preset wins over the matugen scheme.
function current(activePreset, matugenScheme) {
    if (activePreset)
        return "preset:" + activePreset;
    return matugenScheme ? "matugen:" + matugenScheme : "";
}

function parse(value) {
    var s = String(value || "");
    var at = s.indexOf(":");
    return at < 0 ? null : { "kind": s.slice(0, at), "id": s.slice(at + 1) };
}
