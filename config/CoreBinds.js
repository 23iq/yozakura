.pragma library
.import "../modules/globals/BrandActions.js" as BrandActions

// Registry of the shell's own keybinds (binds.json "<app>" root and its
// "system" section). One entry per bind: where it lives, its default combo
// and the catalog action (config/KeybindActions.js) it runs. Adding a core
// bind = one entry here + `make schema` (regenerates the typed binds.json
// adapter config/adapters/KeybindsAdapter.qml); the repair pass, the TOML
// payload, the editor and the cheatsheet all read this list.
//
// `action` is an app action name (BrandActions.action(name)) unless it
// contains a dot (a full catalog id such as "system.lock").

var BINDS = [
    { "section": "", "name": "launcher", "modifiers": ["SUPER"], "key": "Super_L", "action": "launcher" },
    { "section": "", "name": "dashboard", "modifiers": ["SUPER"], "key": "D", "action": "dashboard" },
    { "section": "", "name": "assistant", "modifiers": ["SUPER"], "key": "A", "action": "assistant" },
    { "section": "", "name": "clipboard", "modifiers": ["SUPER"], "key": "V", "action": "clipboard" },
    { "section": "", "name": "emoji", "modifiers": ["SUPER"], "key": "PERIOD", "action": "emoji" },
    { "section": "", "name": "notes", "modifiers": ["SUPER"], "key": "N", "action": "notes" },
    { "section": "", "name": "tmux", "modifiers": ["SUPER", "ALT"], "key": "T", "action": "tmux" },
    { "section": "", "name": "wallpapers", "modifiers": ["SUPER"], "key": "COMMA", "action": "wallpapers" },
    // Voice input: hold to talk (press + release binds), see
    // backend/pkg/svc/compositor/holdbinds.go
    { "section": "", "name": "voiceAi", "modifiers": ["SUPER"], "key": "M", "action": "voice-ai" },
    { "section": "", "name": "dictation", "modifiers": ["SUPER", "SHIFT"], "key": "M", "action": "dictation" },
    { "section": "system", "name": "overview", "modifiers": ["SUPER"], "key": "TAB", "action": "overview" },
    { "section": "system", "name": "powermenu", "modifiers": ["SUPER"], "key": "ESCAPE", "action": "powermenu" },
    { "section": "system", "name": "config", "modifiers": ["SUPER", "SHIFT"], "key": "C", "action": "config" },
    { "section": "system", "name": "lockscreen", "modifiers": ["SUPER"], "key": "L", "action": "system.lock" },
    { "section": "system", "name": "tools", "modifiers": ["SUPER"], "key": "S", "action": "tools" },
    { "section": "system", "name": "screenshot", "modifiers": ["SUPER", "SHIFT"], "key": "S", "action": "screenshot" },
    { "section": "system", "name": "screenrecord", "modifiers": ["SUPER", "SHIFT"], "key": "R", "action": "screenrecord" },
    { "section": "system", "name": "lens", "modifiers": ["SUPER", "SHIFT"], "key": "A", "action": "lens" },
    { "section": "system", "name": "reload", "modifiers": ["SUPER", "ALT"], "key": "B", "action": "reload" },
    { "section": "system", "name": "quit", "modifiers": ["SUPER", "CTRL", "ALT"], "key": "B", "action": "quit" },
    { "section": "system", "name": "bar", "modifiers": ["SUPER", "SHIFT"], "key": "B", "action": "bar" },
    { "section": "system", "name": "keybinds", "modifiers": ["SUPER"], "key": "SLASH", "action": "keybinds" }
];

function actionId(entry) {
    return entry.action.indexOf(".") !== -1 ? entry.action : BrandActions.action(entry.action);
}

// "launcher" / "system.tools": the bind's path below the app root, also
// the id stored in the adapter's `disabled` list.
function path(entry) {
    return entry.section ? entry.section + "." + entry.name : entry.name;
}

function names(section) {
    return BINDS.filter(function (b) {
        return b.section === (section || "");
    }).map(function (b) {
        return b.name;
    });
}

function byPath(p) {
    for (var i = 0; i < BINDS.length; i++) {
        if (path(BINDS[i]) === p)
            return BINDS[i];
    }
    return null;
}

// Default bind object as stored in binds.json.
function defaultBind(entry) {
    return {
        "modifiers": entry.modifiers.slice(),
        "key": entry.key,
        "action": {
            "id": actionId(entry),
            "args": {}
        }
    };
}

// The bind stored at `entry` in a binds.json-shaped object (`root` is the
// app root, e.g. data[appId]), or null.
function lookup(root, entry) {
    if (!root)
        return null;
    var holder = entry.section ? root[entry.section] : root;
    return holder ? (holder[entry.name] || null) : null;
}
