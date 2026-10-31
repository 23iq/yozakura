.pragma library
.import "../../config/JsonUtil.js" as JsonUtil

// Pure helpers for the routine editor's tool steps. The catalog comes from
// the backend (`routines.tools`: [{name, title, description, category,
// summary, schema}], the schema being the MCP tool's input schema); this file
// derives the argument form, the validation messages and the one-line
// sentence of a step from it. `tr(key)` returns the translation or "" (the
// backend's English text is the fallback). Tested in tests/routines.test.cjs.

// Friendly starting arguments (UX, not schema) of the common tools.
var DEFAULTS = {
    dnd_set: { enabled: true }, nightlight_set: { enabled: true }, caffeine_set: { enabled: true },
    wifi_toggle: { enabled: true }, volume_set: { percent: 50 }, brightness_set: { percent: 50 },
    media_control: { action: "play-pause" }, focus_start: { minutes: 25 }, timer_start: { duration: "25m" },
    screenshot: { mode: "full" }, stopwatch_control: { action: "toggle" }, timer_control: { action: "pause" },
    workspace_switch: { workspace: 1 }, shell_toggle: { panel: "launcher" }
};

var UNITS = { percent: "%", delta: "%", minutes: "min", temperature: "K" };

function clone(v) {
    return JsonUtil.clone(v === undefined ? null : v);
}

function prettify(id) {
    var s = String(id || "").replace(/[_-]+/g, " ").trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
}

function trOr(tr, key, fallback) {
    var s = tr ? tr(key) : "";
    return s ? s : fallback;
}

function byName(list) {
    var out = {};
    (list || []).forEach(function (t) {
        out[t.name] = t;
    });
    return out;
}

function title(tool, tr) {
    return trOr(tr, "routines.tool." + tool.name, tool.title || prettify(tool.name));
}

function description(tool, tr) {
    var full = String(tool.description || "");
    var cut = full.indexOf(". ");
    var first = cut >= 0 ? full.substring(0, cut + 1) : full;
    return trOr(tr, "routines.tool." + tool.name + ".desc", first);
}

// Name of a step's tool for headers: the catalog title, or the typed id
// prettified ("custom_tool" -> "Custom tool").
function toolTitle(name, catalog, tr) {
    var t = byName(catalog)[name];
    return t ? title(t, tr) : prettify(name);
}

function matches(tool, q, tr) {
    var hay = (title(tool, tr) + " " + description(tool, tr) + " " + tool.name.replace(/_/g, " ")).toLowerCase();
    return q.split(/\s+/).every(function (w) {
        return hay.indexOf(w) >= 0;
    });
}

// Picker content: [{category, tools: [tool]}] in the backend's category
// order, filtered by the words of `query` (title, description, id).
function groups(catalog, categories, query, tr) {
    var q = String(query || "").trim().toLowerCase();
    var order = categories || [];
    var out = [];
    order.forEach(function (c) {
        var tools = (catalog || []).filter(function (t) {
            return t.category === c && (q === "" || matches(t, q, tr));
        });
        if (tools.length)
            out.push({ category: c, tools: tools });
    });
    return out;
}

function schemaOf(tool) {
    var s = tool && tool.schema;
    return s && typeof s === "object" ? s : { properties: {} };
}

// The argument fields of a tool, in schema order:
// {key, kind, options, min, max, step, unit, required, def, hint}
// kind: enum | triple (true/false/"toggle") | switch | tristate (on / off /
// not set) | slider | number | text | json.
function fields(tool) {
    var s = schemaOf(tool);
    var props = s.properties || {};
    var required = s.required || [];
    return Object.keys(props).map(function (key) {
        var p = props[key] || {};
        var types = Array.isArray(p.type) ? p.type : (p.type ? [p.type] : []);
        var f = { key: key, kind: "json", required: required.indexOf(key) >= 0, def: p.default, hint: p.description || "", unit: UNITS[key] || "" };
        if (p.enum) {
            f.kind = "enum";
            f.options = p.enum.slice();
        } else if (types.indexOf("boolean") >= 0 && types.indexOf("string") >= 0) {
            f.kind = "triple";
        } else if (types.length === 1 && types[0] === "boolean") {
            f.kind = f.required || p.default !== undefined ? "switch" : "tristate";
        } else if (types.length === 1 && (types[0] === "number" || types[0] === "integer")) {
            f.integer = types[0] === "integer";
            f.min = p.minimum;
            f.max = p.maximum;
            var range = f.max - f.min;
            f.kind = isFinite(range) ? "slider" : "number";
            f.step = f.integer ? (range >= 2000 ? 100 : 1) : (range <= 10 ? 0.1 : 1);
        } else if (types.length && types.every(function (t) {
            return t === "string" || t === "integer";
        })) {
            f.kind = "text";
        }
        return f;
    });
}

// Arguments of a new step: the friendly defaults, then required fields.
function defaultArgs(tool) {
    var out = clone(DEFAULTS[tool.name] || {});
    fields(tool).forEach(function (f) {
        if (!f.required || out[f.key] !== undefined)
            return;
        if (f.kind === "enum")
            out[f.key] = f.options[0];
        else if (f.kind === "slider" || f.kind === "number")
            out[f.key] = f.min !== undefined ? f.min : 0;
        else if (f.kind === "switch")
            out[f.key] = true;
    });
    return out;
}

function newStep(tool) {
    return { kind: "tool", tool: tool.name, args: defaultArgs(tool) };
}

function empty(v) {
    return v === undefined || v === null || v === "";
}

// args with `key` set; an empty value removes it (optional arguments stay
// out of the saved step).
function withArg(args, key, value) {
    var out = clone(args || {});
    if (empty(value))
        delete out[key];
    else
        out[key] = value;
    return out;
}

// Problems of args against the tool's schema: [{key, code, min, max}]
// code: required | min | max | enum | type | unknown.
function validate(tool, args) {
    var out = [];
    var a = args || {};
    var fs = fields(tool);
    var known = {};
    fs.forEach(function (f) {
        known[f.key] = true;
        var v = a[f.key];
        if (empty(v)) {
            if (f.required)
                out.push({ key: f.key, code: "required" });
            return;
        }
        if (f.kind === "enum" && f.options.indexOf(v) < 0)
            out.push({ key: f.key, code: "enum" });
        else if (f.kind === "slider" || f.kind === "number") {
            if (typeof v !== "number" || isNaN(v))
                out.push({ key: f.key, code: "type" });
            else if (f.min !== undefined && v < f.min)
                out.push({ key: f.key, code: "min", min: f.min });
            else if (f.max !== undefined && v > f.max)
                out.push({ key: f.key, code: "max", max: f.max });
        } else if ((f.kind === "switch" || f.kind === "tristate") && typeof v !== "boolean")
            out.push({ key: f.key, code: "type" });
    });
    Object.keys(a).forEach(function (k) {
        if (!known[k] && schemaOf(tool).additionalProperties === false)
            out.push({ key: k, code: "unknown" });
    });
    return out;
}

// --- the one-line sentence ----------------------------------------------

// Fills a summary template (same language as backend routinetools.Render):
// {key} value; {key|true=on|false=off|unset=toggle|*=x} by value;
// [ ... ] dropped when an argument inside is unset, `||` separates
// alternatives.
function placeholder(spec, args) {
    var parts = spec.split("|");
    var raw = args ? args[parts[0]] : undefined;
    var set = !empty(raw);
    var val = set ? String(raw) : "unset";
    if (parts.length === 1)
        return { text: set ? val : "", set: set };
    var def = "";
    for (var i = 1; i < parts.length; i++) {
        var eq = parts[i].indexOf("=");
        if (eq < 0)
            continue;
        var k = parts[i].substring(0, eq);
        var text = parts[i].substring(eq + 1);
        if (k === val)
            return { text: text, set: true };
        if (k === "*")
            def = text;
    }
    return { text: def !== "" ? def : val, set: set };
}

function renderAll(text, args) {
    var out = "";
    for (var i = 0; i < text.length;) {
        if (text.charAt(i) !== "{") {
            out += text.charAt(i++);
            continue;
        }
        var end = text.indexOf("}", i);
        if (end < 0)
            return { text: out + text.substring(i), ok: true };
        var p = placeholder(text.substring(i + 1, end), args);
        if (!p.set)
            return { text: "", ok: false };
        out += p.text;
        i = end + 1;
    }
    return { text: out, ok: true };
}

function render(tpl, args) {
    var out = "";
    for (var i = 0; i < tpl.length;) {
        var c = tpl.charAt(i);
        var end;
        if (c === "[" && (end = tpl.indexOf("]", i)) >= 0) {
            var alts = tpl.substring(i + 1, end).split("||");
            for (var j = 0; j < alts.length; j++) {
                var r = renderAll(alts[j], args);
                if (r.ok) {
                    out += r.text;
                    break;
                }
            }
            i = end + 1;
        } else if (c === "{" && (end = tpl.indexOf("}", i)) >= 0) {
            out += placeholder(tpl.substring(i + 1, end), args).text;
            i = end + 1;
        } else {
            out += c;
            i++;
        }
    }
    var s = out.split(/\s+/).filter(Boolean).join(" ").replace(/^,\s*/, "").trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
}

// "Turn on Do Not Disturb": the translated template, else the backend's
// English one, else the title; `fallback` is the backend label of a step
// the catalog does not know.
function summary(step, catalog, tr, fallback) {
    var t = byName(catalog)[step.tool];
    if (!t)
        return fallback || prettify(step.tool);
    var tpl = trOr(tr, "routines.tool." + t.name + ".summary", t.summary || "");
    var s = tpl ? render(tpl, step.args || {}) : "";
    return s !== "" ? s : title(t, tr);
}

// Translation key of an enum value label: tool-specific first, then generic.
function valueKeys(tool, field, value) {
    return ["routines.value." + tool + "." + field + "." + value, "routines.enum." + value];
}

function valueLabel(tool, field, value, tr) {
    var keys = valueKeys(tool, field, value);
    return trOr(tr, keys[0], trOr(tr, keys[1], String(value)));
}

function fieldLabel(tool, key, tr) {
    return trOr(tr, "routines.field." + tool + "." + key, trOr(tr, "routines.field." + key, prettify(key)));
}

function fieldHint(tool, key, fallback, tr) {
    return trOr(tr, "routines.field." + tool + "." + key + ".hint", trOr(tr, "routines.field." + key + ".hint", fallback || ""));
}
