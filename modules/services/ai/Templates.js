.pragma library

// Prompt-library templates: "{name}" placeholders filled from context.
// Known variables: selection, clipboard, date, time, datetime, file, window,
// language, input (anything else is left untouched, so prompts can talk
// about JSON braces safely). "{{" and "}}" escape literal braces.

var KNOWN = ["selection", "clipboard", "date", "time", "datetime", "file", "window", "language", "input"];
var PLACEHOLDER = /\{([a-z_]+)\}/g;

// Variables a template needs, so callers only read what is used
// (reading the selection or clipboard spawns processes).
function variables(template) {
    var found = [];
    var text = String(template || "").replace(/\{\{|\}\}/g, "");
    var m;
    PLACEHOLDER.lastIndex = 0;
    while ((m = PLACEHOLDER.exec(text)) !== null) {
        if (KNOWN.indexOf(m[1]) >= 0 && found.indexOf(m[1]) < 0)
            found.push(m[1]);
    }
    return found;
}

function _pad(n) {
    return n < 10 ? "0" + n : String(n);
}

function dateVars(now) {
    var d = now || new Date();
    var date = d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate());
    var time = _pad(d.getHours()) + ":" + _pad(d.getMinutes());
    return { date: date, time: time, datetime: date + " " + time };
}

// vars: {selection, clipboard, file, window, language, input}; dates are added.
function expand(template, vars, now) {
    var values = dateVars(now);
    var v = vars || {};
    for (var k in v)
        values[k] = v[k];
    var out = String(template || "").replace(/\{\{/g, "\u0001").replace(/\}\}/g, "\u0002");
    out = out.replace(PLACEHOLDER, function (all, name) {
        if (KNOWN.indexOf(name) < 0)
            return all;
        var value = values[name];
        return value === undefined || value === null ? "" : String(value);
    });
    return out.replace(/\u0001/g, "{").replace(/\u0002/g, "}");
}

// True when the template references text the user must provide.
function needsInput(template) {
    return variables(template).indexOf("input") >= 0;
}
