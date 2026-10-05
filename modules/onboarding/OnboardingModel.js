.pragma library

// Pure helpers of the onboarding wizard (tested in tests/onboarding.test.cjs):
// environment detection (one shell probe, parsed here), the keybind tour,
// preset mini-preview looks and voice setup progress.

// Terminals offered in the system step, in preference order.
var TERMINALS = ["kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "st"];

// AI agents/runtimes detected in the AI step. `config` is the ai.agents.<id>
// block the toggle writes (none for Ollama: its local models show up in
// the model list by themselves when the daemon runs).
var AGENTS = [
    { "id": "claude", "label": "Claude Code", "icon": "sparkle", "config": "claude", "install": "onboarding.ai.claude.install" },
    { "id": "codex", "label": "Codex", "icon": "code", "config": "codex", "install": "onboarding.ai.codex.install" },
    { "id": "opencode", "label": "OpenCode", "icon": "terminalWindow", "config": "opencode", "install": "onboarding.ai.opencode.install" },
    { "id": "ollama", "label": "Ollama", "icon": "cube", "config": "", "install": "onboarding.ai.ollama.install" }
];

// Interactive keybind tour: `command` is the GlobalShortcuts.run() command
// the bound action dispatches, `action` the action-id suffix of the bind.
var TOUR = [
    { "id": "cheatsheet", "command": "keybinds", "action": "keybinds", "icon": "keyboard", "title": "onboarding.tour.cheatsheet", "hint": "onboarding.tour.cheatsheet.hint" },
    { "id": "launcher", "command": "launcher", "action": "launcher", "icon": "magnifyingGlass", "title": "onboarding.tour.launcher", "hint": "onboarding.tour.launcher.hint" },
    { "id": "assistant", "command": "assistant", "action": "assistant", "icon": "sparkle", "title": "onboarding.tour.assistant", "hint": "onboarding.tour.assistant.hint" },
    { "id": "overview", "command": "overview", "action": "overview", "icon": "squaresFour", "title": "onboarding.tour.overview", "hint": "onboarding.tour.overview.hint" }
];

// Shell probe run once when the wizard opens. Prints key=value lines.
// Run as `bash -c SCRIPT NAME DATA_DIR`: the data dir is $1.
function detectScript() {
    return [
        "for t in " + TERMINALS.join(" ") + "; do command -v \"$t\" >/dev/null 2>&1 && echo \"term=$t\"; done",
        "for a in " + AGENTS.map(function (a) {
            return a.id;
        }).join(" ") + "; do p=$(command -v \"$a\" 2>/dev/null) && echo \"agent=$a:$p\"; done",
        "d=\"$1/whisper\"",
        "[ -x \"$d/bin/whisper-server\" ] && echo whisper=bin",
        "ls \"$d/models\"/ggml-*.bin >/dev/null 2>&1 && echo whisper=model",
        "command -v nvcc >/dev/null 2>&1 && echo gpu=cuda",
        "echo done=1"
    ].join("\n");
}

function parseDetect(text) {
    var out = {
        "terminals": [],
        "agents": {},
        "whisper": {
            "installed": false,
            "model": false
        },
        "cuda": false,
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
        } else if (key === "agent") {
            var c = val.indexOf(":");
            var id = c > 0 ? val.substring(0, c) : val;
            if (agent(id))
                out.agents[id] = c > 0 ? val.substring(c + 1) : "";
        } else if (key === "whisper") {
            if (val === "bin")
                out.whisper.installed = true;
            else if (val === "model")
                out.whisper.model = true;
        } else if (key === "gpu") {
            out.cuda = val === "cuda";
        } else if (key === "done") {
            out.complete = true;
        }
    });
    out.terminals.sort(function (a, b) {
        return TERMINALS.indexOf(a) - TERMINALS.indexOf(b);
    });
    return out;
}

function agent(id) {
    for (var i = 0; i < AGENTS.length; i++) {
        if (AGENTS[i].id === id)
            return AGENTS[i];
    }
    return null;
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

// scripts/voice_setup.sh prints "info" lines on stderr; map them to a
// 0..1 progress and a short stage name for the progress bar.
var VOICE_STAGES = [
    { "match": /Removing previous build|Cloning|Updating whisper/, "stage": "fetch", "progress": 0.1 },
    { "match": /Configuring/, "stage": "configure", "progress": 0.2 },
    { "match": /Building/, "stage": "build", "progress": 0.3 },
    { "match": /Installed whisper/, "stage": "installed", "progress": 0.6 },
    { "match": /Model present|Downloading/, "stage": "model", "progress": 0.7 },
    { "match": /^Done\.|:: Done\./, "stage": "done", "progress": 1 }
];

function stripAnsi(s) {
    return String(s || "").replace(/\x1b\[[0-9;]*m/g, "");
}

function voiceProgress(line, previous) {
    var text = stripAnsi(line).replace(/^::\s*/, "").trim();
    var p = previous || 0;
    for (var i = 0; i < VOICE_STAGES.length; i++) {
        if (VOICE_STAGES[i].match.test(text))
            return {
                "stage": VOICE_STAGES[i].stage,
                "progress": Math.max(p, VOICE_STAGES[i].progress),
                "text": text
            };
    }
    return {
        "stage": "",
        "progress": p,
        "text": text
    };
}
