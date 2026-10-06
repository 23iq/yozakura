.pragma library

// Pure helpers of the onboarding wizard (tested in tests/onboarding.test.cjs):
// terminal detection (one shell probe, parsed here), the keybind tour,
// preset mini-preview looks and the Ollama model chips of the AI step.

// Terminals offered in the system step, in preference order.
var TERMINALS = ["kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "st"];

// Interactive keybind tour: `command` is the GlobalShortcuts.run() command
// the bound action dispatches, `action` the action-id suffix of the bind.
var TOUR = [
    { "id": "cheatsheet", "command": "keybinds", "action": "keybinds", "icon": "keyboard", "title": "onboarding.tour.cheatsheet", "hint": "onboarding.tour.cheatsheet.hint" },
    { "id": "launcher", "command": "launcher", "action": "launcher", "icon": "magnifyingGlass", "title": "onboarding.tour.launcher", "hint": "onboarding.tour.launcher.hint" },
    { "id": "assistant", "command": "assistant", "action": "assistant", "icon": "sparkle", "title": "onboarding.tour.assistant", "hint": "onboarding.tour.assistant.hint" },
    { "id": "overview", "command": "overview", "action": "overview", "icon": "squaresFour", "title": "onboarding.tour.overview", "hint": "onboarding.tour.overview.hint" }
];

// Shell probe run once when the wizard opens (`bash -c SCRIPT`). Prints
// key=value lines.
function detectScript() {
    return [
        "for t in " + TERMINALS.join(" ") + "; do command -v \"$t\" >/dev/null 2>&1 && echo \"term=$t\"; done",
        "echo done=1"
    ].join("\n");
}

function parseDetect(text) {
    var out = {
        "terminals": [],
        "complete": false
    };
    String(text || "").split("\n").forEach(function (raw) {
        var line = raw.trim();
        var eq = line.indexOf("=");
        if (eq <= 0)
            return;
        var key = line.substring(0, eq);
        var val = line.substring(eq + 1);
        if (key === "term" && TERMINALS.indexOf(val) !== -1 && out.terminals.indexOf(val) === -1) {
            out.terminals.push(val);
        } else if (key === "done") {
            out.complete = true;
        }
    });
    out.terminals.sort(function (a, b) {
        return TERMINALS.indexOf(a) - TERMINALS.indexOf(b);
    });
    return out;
}

// Screen diagonal in inches (one decimal) from the physical size the
// compositor reports; 0 when it is unknown (projectors, some VMs).
function diagonalInches(output) {
    var w = output && output.physical_width_mm > 0 ? output.physical_width_mm : 0;
    var h = output && output.physical_height_mm > 0 ? output.physical_height_mm : 0;
    if (!w || !h)
        return 0;
    return Math.round(Math.sqrt(w * w + h * h) / 25.4 * 10) / 10;
}

// Terminal chips: the detected ones, plus the configured one if it is not
// among them (so the current choice is always visible).
function terminalChoices(detected, current) {
    var list = (detected || []).slice();
    if (current && list.indexOf(current) === -1)
        list.unshift(current);
    return list;
}

// Language chips: "auto" first, then the translation catalog (code -> name).
function languageChoices(available) {
    var out = [{
            "code": "auto",
            "name": ""
        }];
    Object.keys(available || {}).sort().forEach(function (code) {
        out.push({
            "code": code,
            "name": available[code]
        });
    });
    return out;
}

// First enabled bind (BindModel rows) whose actions include actionId.
function findKeys(rows, actionId) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!r || r.enabled === false || !r.keys || r.keys.length === 0)
            continue;
        var acts = r.actions || [];
        for (var j = 0; j < acts.length; j++) {
            if (acts[j] && acts[j].id === actionId && r.keys[0].key)
                return r.keys[0];
        }
    }
    return null;
}

function tourDone(state) {
    return TOUR.every(function (t) {
        return state && (state[t.id] === "done" || state[t.id] === "skipped");
    });
}

// Mini-preview look of a preset from its bar.json / theme.json (either may
// be missing: the current values fill in).
function presetLook(bar, theme, fallback) {
    var b = bar || {};
    var t = theme || {};
    var f = fallback || {};
    var layout = b.layout || {};
    var pos = b.position || f.position || "top";
    return {
        "position": ["top", "bottom", "left", "right"].indexOf(pos) !== -1 ? pos : "top",
        "style": layout.style || f.style || "classic",
        "frame": b.frameEnabled !== undefined ? b.frameEnabled === true : f.frame === true,
        "roundness": typeof t.roundness === "number" ? t.roundness : (typeof f.roundness === "number" ? f.roundness : 12),
        "light": t.lightMode !== undefined ? t.lightMode === true : f.light === true,
        "oled": t.oledMode !== undefined ? t.oledMode === true : f.oled === true,
        "font": t.font || f.font || ""
    };
}

// Models the AI step offers to pull once Ollama is installed.
var OLLAMA_MODELS = [
    { "id": "llama3.2", "label": "Llama 3.2", "size": "2 GB" },
    { "id": "qwen2.5-coder", "label": "Qwen 2.5 Coder", "size": "4.7 GB" },
    { "id": "gemma3", "label": "Gemma 3", "size": "3.3 GB" }
];

// Chip state of one model pull from its job progress (null: never asked
// for in this session): "idle" | "pulling" (percent, -1 unknown) | "done"
// | "failed".
function pullState(progress, requested) {
    if (!progress)
        return { "state": requested ? "pulling" : "idle", "percent": -1 };
    if (progress.state === "done")
        return { "state": "done", "percent": 100 };
    if (progress.state === "failed")
        return { "state": "failed", "percent": -1 };
    if (progress.state === "cancelled")
        return { "state": "idle", "percent": -1 };
    return { "state": "pulling", "percent": progress.state === "running" && progress.percent >= 0 ? progress.percent : -1 };
}
