.pragma library

// Dry run (`<app> onboarding --dry-run`): which daemon methods may reach the
// real daemon and the journal line of the ones that are mocked. Fail closed:
// only the reads below pass (exact names, safe verbs, yozd CLI queries);
// everything else is answered by DryRunBackend.js.

function _num(v) {
    var n = Number(v);
    return isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

function _sameOutput(a, b) {
    var keys = ["width", "height", "refresh", "scale", "x", "y", "transform"];
    for (var i = 0; i < keys.length; i++) {
        if (_num(a[keys[i]]) !== _num(b[keys[i]]))
            return false;
    }
    return (a.enabled !== false) === (b.enabled !== false);
}

function _outputText(o) {
    if (o.enabled === false)
        return o.name + " off";
    var s = o.name + " " + _num(o.width) + "x" + _num(o.height) + "@" + _num(o.refresh);
    if (o.scale && _num(o.scale) !== 1)
        s += " scale " + _num(o.scale);
    return s;
}

function _displaysLine(state, params) {
    var outs = (params && params.outputs) || [];
    var changed = outs.filter(function (o) {
        var cur = state.outputs.filter(function (c) {
            return c.name === o.name;
        })[0];
        return !cur || !_sameOutput(cur, o);
    });
    var list = changed.length > 0 ? changed : outs;
    return "apply display " + (list.length > 0 ? list.map(_outputText).join("; ") : "(no change)");
}

function _keyboardLine(p) {
    var layouts = ((p && p.layouts) || []).map(function (l) {
        return (l.layout || "") + (l.variant ? "(" + l.variant + ")" : "");
    });
    var parts = ["set keyboard", layouts.join(",")];
    if (p && p.switchBind)
        parts.push(p.switchBind);
    if (p && p.options && p.options.length > 0)
        parts.push(p.options.join(","));
    return parts.join(" ");
}

function _brief(v) {
    var s = typeof v === "string" ? v : JSON.stringify(v);
    return s && s.length > 80 ? s.substring(0, 77) + "..." : String(s);
}

// Mocked method -> its journal line (null: kept quiet). Any other mocked
// method is journaled as "unmocked call <method>".
var METHODS = {
    "displays.apply": function (p, s) {
        return _displaysLine(s, p);
    },
    "displays.keep": function () {
        return "keep display change";
    },
    "displays.revert": function () {
        return "revert display change";
    },
    "displays.moveConflicts": function () {
        return "move monitor rules out of the compositor config";
    },
    "keyboard.apply": function (p) {
        return _keyboardLine(p);
    },
    "keyboard.next": function () {
        return "switch to the next keyboard layout";
    },
    "displays.identify": function () {
        return null;
    },
    "keystore.list": function () {
        return null;
    },
    "keystore.set": function (p) {
        return "save the API key of " + (p && p.provider);
    },
    "keystore.delete": function (p) {
        return "remove the API key of " + (p && p.provider);
    },
    "extras.install": function (p) {
        return "install " + ((p && p.ids) || []).join(", ") + (p && p.confirmMultilib ? " (enable multilib)" : "");
    },
    "extras.cancel": function (p) {
        return "cancel install job " + (p && p.job);
    },
    "extras.upgradeAndRetry": function (p) {
        return "upgrade the system and retry job " + (p && p.job);
    },
    "extras.ollamaPull": function (p) {
        return "pull ollama model " + (p && p.model);
    },
    "extras.setLoginShell": function (p) {
        return "set login shell " + (p && p.shell);
    },
    "term.apply": function () {
        return "write the terminal prompt files";
    },
    "exclusive.enable": function () {
        return "make exclusive";
    },
    "exclusive.restore": function () {
        return "leave exclusive mode";
    },
    "preset.load": function (p) {
        return "apply preset " + (p && p.name);
    },
    "wallpaper.set": function (p) {
        return "set wallpaper " + (p && p.path);
    },
    "apphooks.apply": function () {
        return "connect app themes";
    },
    "apphooks.revert": function () {
        return "disconnect app themes";
    },
    "apphooks.ensure": function () {
        return null;
    },
    "config.write": function (p) {
        return "write config " + _brief(p && (p.domain || p.file || p.name));
    },
    "config.patch": function (p) {
        return "patch config " + _brief(p);
    },
    "config.stateSet": function () {
        return null;
    },
    "config.statesSet": function () {
        return null;
    },
    "compositor.write": function () {
        return "write the compositor config";
    },
    "compositor.dispatch": function (p) {
        return "compositor " + _brief(p && p.args ? p.args.join(" ") : p);
    },
    "compositor.eval": function (p) {
        return "compositor eval " + _brief(p && (p.expression || p));
    }
};

// Reads by exact name, and by verb (the part after the last dot).
var READS = ["config.statesGet", "compositor.state", "keyboard.current"];
// Read-named but kept away from the daemon: identify draws on the real
// shell too (mocked locally), API keys are never read in a dry run.
var NOT_READS = ["displays.identify"];
var READ_VERB = /^(list|status|catalog|get.*|preview|presets|plan|log|probe|conflicts|identify|state|statesGet)$/;

// compositor.dispatch runs a daemon CLI command: queries ("layout list",
// "system get-compositor", "monitor status") are reads.
// Nouns of the yozd CLI (backend/cmd/yozd main.go); no argument may look
// like an option ("-c other.toml" must never pass as a query).
var YOZD_NOUNS = ["window", "workspace", "monitor", "keyboard", "layout", "config", "system", "darkmode", "brightness", "overview"];

function _isQuery(params) {
    var a = (params && params.args) || [];
    if (!Array.isArray(a) || YOZD_NOUNS.indexOf(a[0]) < 0)
        return false;
    for (var i = 0; i < a.length; i++) {
        if (typeof a[i] !== "string" || a[i].charAt(0) === "-")
            return false;
    }
    var verb = String(a[1] || "");
    return verb === "list" || verb === "status" || /^get(-|$)/.test(verb);
}

function isRead(method, params) {
    var m = String(method || "");
    if (m === "compositor.dispatch")
        return _isQuery(params);
    if (READS.indexOf(m) >= 0)
        return true;
    if (NOT_READS.indexOf(m) >= 0 || m.indexOf("keystore.") === 0)
        return false;
    var dot = m.lastIndexOf(".");
    return dot > 0 && READ_VERB.test(m.substring(dot + 1));
}

// Params of a read as sent to the daemon: extras.status never forces a
// re-detection (that would broadcast to the real shell).
function readParams(method, params) {
    if (method === "extras.status" && params && params.refresh)
        return {};
    return params;
}

function isMutating(method, params) {
    return !isRead(method, params);
}

// Journal line of a mocked call (null: not journaled).
function line(method, params, state) {
    if (!Object.prototype.hasOwnProperty.call(METHODS, method))
        return "unmocked call " + method;
    return METHODS[method](params || {}, state);
}
