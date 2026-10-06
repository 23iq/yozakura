.pragma library

// Type roles: body text follows theme.font; headings follow theme.type.heading
// (empty = the body font) and are cased by theme.type.headingCase.
var CASES = ["none", "upper", "lower", "title"];

function headingCase(mode) {
    return CASES.indexOf(mode) === -1 ? "none" : mode;
}

function applyCase(text, mode) {
    var s = text === undefined || text === null ? "" : String(text);
    switch (headingCase(mode)) {
    case "upper":
        return s.toUpperCase();
    case "lower":
        return s.toLowerCase();
    case "title":
        return s.toLowerCase().replace(/(^|[\s\-\/])(\S)/g, function (m, sep, c) {
            return sep + c.toUpperCase();
        });
    default:
        return s;
    }
}

function headingFamily(typeCfg, bodyFont) {
    var h = typeCfg && typeCfg.heading ? String(typeCfg.heading) : "";
    return h !== "" ? h : bodyFont;
}
