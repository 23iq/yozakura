.pragma library

// Launcher "> command" logic over the shell command registry
// (assets/commands/commands.json, shared with `<app> cmd` and the MCP
// shell_command tool). Pure: the QML provider passes the registry entries
// (with a translated `label`) and the preset names.

function _words(s) {
    return String(s || "").toLowerCase().trim().split(/\s+/).filter(w => w !== "");
}

function _hay(cmd) {
    return (cmd.id + " " + (cmd.label || "") + " " + (cmd.keywords || "")).toLowerCase();
}

// Normalizes an argument; returns {ok, value, error, suggestions}.
//   value: the string handed to the run spec ({arg})
function checkArg(cmd, arg, presets) {
    const spec = cmd.arg;
    const raw = String(arg === undefined || arg === null ? "" : arg).trim();
    if (!spec || spec.kind === "none")
        return raw === "" ? {
            "ok": true,
            "value": ""
        } : {
            "ok": true,
            "value": "",
            "ignored": raw
        };
    if (raw === "") {
        if (spec["default"] !== undefined)
            return {
                "ok": true,
                "value": String(spec["default"])
            };
        return {
            "ok": !spec.required,
            "value": "",
            "error": spec.required ? "missing" : ""
        };
    }
    if (spec.kind === "number") {
        const n = Number(raw.replace(",", "."));
        if (!isFinite(n))
            return {
                "ok": false,
                "error": "number"
            };
        if ((spec.min !== undefined && n < spec.min) || (spec.max !== undefined && n > spec.max))
            return {
                "ok": false,
                "error": "range"
            };
        return {
            "ok": true,
            "value": String(n)
        };
    }
    if (spec.kind === "enum") {
        const low = raw.toLowerCase();
        const vals = spec.values || [];
        if (vals.indexOf(low) !== -1)
            return {
                "ok": true,
                "value": low
            };
        return {
            "ok": false,
            "error": "enum",
            "suggestions": vals.filter(v => v.indexOf(low) === 0)
        };
    }
    if (spec.kind === "preset") {
        const names = presets || [];
        const low = raw.toLowerCase();
        const exact = names.filter(n => n.toLowerCase() === low);
        if (exact.length)
            return {
                "ok": true,
                "value": exact[0]
            };
        const hits = names.filter(n => n.toLowerCase().indexOf(low) !== -1);
        if (hits.length === 1)
            return {
                "ok": true,
                "value": hits[0]
            };
        if (names.length === 0)
            return {
                "ok": true,
                "value": raw
            };
        return {
            "ok": false,
            "error": hits.length ? "ambiguous" : "unknown",
            "suggestions": hits
        };
    }
    return {
        "ok": true,
        "value": raw
    };
}

// Values offered for an argument (enum values, preset names) filtered by
// what is typed so far.
function argChoices(cmd, typed, presets) {
    const spec = cmd.arg;
    if (!spec)
        return [];
    const low = String(typed || "").trim().toLowerCase();
    let vals = [];
    if (spec.kind === "enum")
        vals = spec.values || [];
    else if (spec.kind === "preset")
        vals = presets || [];
    return vals.filter(v => low === "" || v.toLowerCase().indexOf(low) !== -1);
}

// Mixed searches (no prefix) only take a command when every word is the
// start of its id or a whole keyword: "dnd", "lock", "random wallpaper",
// not "fi" (inside "notifications").
function _strong(cmd, words) {
    const keys = _words(cmd.keywords).concat(_words(cmd.label));
    return words.every(w => (w.length >= 2 && cmd.id.indexOf(w) === 0) || keys.indexOf(w) !== -1);
}

function _score(cmd, words) {
    if (words.length === 0)
        return 1;
    const hay = _hay(cmd);
    let score = 0;
    for (let i = 0; i < words.length; i++) {
        const w = words[i];
        if (cmd.id === w)
            score += 100;
        else if (cmd.id.indexOf(w) === 0)
            score += 60;
        else if (hay.indexOf(w) !== -1)
            score += 20;
        else
            return 0;
    }
    return score;
}

// Results for `query` (the text after the prefix, or the whole search in
// mixed mode). Returns [{cmd, arg, check, choice}] best first:
//   * "<id> <arg>": the command with that argument; for enum/preset
//     arguments also one row per matching choice
//   * words matching id/label/keywords: the command (an enum value among the
//     words becomes the argument: "random wallpaper")
// `mixed` keeps only strong matches (an id prefix or every word matching).
function match(commands, query, presets, mixed) {
    const words = _words(query);
    const out = [];
    const seen = {};
    const add = (cmd, arg, choice) => {
        const key = cmd.id + "\u0000" + (arg || "");
        if (seen[key])
            return;
        seen[key] = true;
        out.push({
            "cmd": cmd,
            "arg": arg || "",
            "check": checkArg(cmd, arg, presets),
            "choice": !!choice
        });
    };
    if (words.length === 0) {
        if (!mixed)
            commands.forEach(c => add(c, ""));
        return out;
    }
    const head = words[0];
    const rest = String(query).trim().substring(String(query).trim().split(/\s+/)[0].length).trim();
    // 1) exact id: "<id> <arg>"
    commands.forEach(c => {
        if (c.id !== head)
            return;
        const choices = argChoices(c, rest, presets);
        const check = checkArg(c, rest, presets);
        // A bare row only when it can run or there is nothing to pick.
        if (check.ok || choices.length === 0)
            add(c, check.ok && check.value ? check.value : rest);
        choices.slice(0, 8).forEach(v => add(c, v, true));
    });
    // 2) id prefix ("wall", "key")
    if (words.length === 1) {
        commands.forEach(c => {
            if (c.id !== head && c.id.indexOf(head) === 0 && (!mixed || head.length >= 3))
                add(c, "");
        });
    }
    // 3) words over id/label/keywords, an enum value among them is the arg
    const scored = [];
    commands.forEach(c => {
        if (c.id === head)
            return;
        let arg = "";
        let ws = words;
        if (c.arg && c.arg.kind === "enum") {
            const v = words.filter(w => (c.arg.values || []).indexOf(w) !== -1);
            if (v.length) {
                arg = v[0];
                ws = words.filter(w => w !== arg);
                if (ws.length === 0)
                    return;
            }
        }
        const s = _score(c, ws);
        if (s > 0 && (!mixed || _strong(c, ws)))
            scored.push({
                "c": c,
                "s": s,
                "arg": arg
            });
    });
    scored.sort((a, b) => b.s - a.s);
    scored.forEach(x => add(x.c, x.arg));
    return mixed ? out.filter(r => r.check.ok).slice(0, 3) : out;
}

// What running `cmd` with the checked argument `value` does:
//   {kind: "ui"|"toggle", value} | {kind: "cli", argv} | {kind: "config", key, value}
function plan(cmd, value) {
    const run = cmd.run || {};
    const sub = s => String(s).split("{arg}").join(value || "");
    if (run.ui !== undefined)
        return {
            "kind": "ui",
            "value": sub(run.ui)
        };
    if (run.toggle !== undefined)
        return {
            "kind": "toggle",
            "value": sub(run.toggle)
        };
    if (run.cli !== undefined)
        return {
            "kind": "cli",
            "argv": run.cli.map(sub)
        };
    if (run.config !== undefined) {
        let v = value;
        if (run.map && run.map.hasOwnProperty(value))
            v = run.map[value];
        else if (cmd.arg && cmd.arg.kind === "number")
            v = Number(value);
        return {
            "kind": "config",
            "key": run.config,
            "value": v
        };
    }
    return null;
}

// Text the search should become to fill in the argument of `cmd`.
function completion(prefix, cmd, arg) {
    return prefix + cmd.id + " " + (arg || "");
}
