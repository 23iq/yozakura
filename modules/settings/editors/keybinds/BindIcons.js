.pragma library
.import "../../../globals/BrandActions.js" as BrandActions

// The icon of a bind in the shortcuts list (an Icons name): what its first
// action does (a window closes, the screen locks, a screenshot is taken),
// not one icon for the whole group. The shell's own actions
// ("<app>.launcher") by their name, catalog actions by id, raw dispatchers
// by what they dispatch; anything else falls back to the group's icon
// (BindModel.GROUPS), then to "command". Pure (tests/settings-bind-icons.test.cjs).

// the shell's own actions, by name (BrandActions.action(name))
var APP = {
    "assistant": "assistant",
    "bar": "sidebarSimple",
    "clipboard": "clipboard",
    "config": "gear",
    "dashboard": "widgets",
    "dictation": "mic",
    "voice-ai": "waveform",
    "emoji": "emoji",
    "keybinds": "keyboard",
    "launcher": "magnifyingGlass",
    "lens": "aperture",
    "notes": "notepad",
    "overview": "squaresFour",
    "powermenu": "power",
    "quit": "xCircle",
    "reload": "arrowsClockwise",
    "screenrecord": "recordScreen",
    "screenshot": "camera",
    "terminal": "terminal",
    "timers": "timer",
    "tmux": "terminalWindow",
    "tools": "toolbox",
    "wallpapers": "wallpapers"
};

// catalog actions (config/KeybindActions.js), by id
var CATALOG = {
    "apps.launch": "appWindow",
    "apps.terminal-run": "terminal",
    "command.run": "terminalWindow",
    "audio.mute-toggle": "speakerSlash",
    "audio.volume-down": "speakerLow",
    "audio.volume-up": "speakerHigh",
    "brightness.down": "sunDim",
    "brightness.up": "sun",
    "media.next": "next",
    "media.prev": "previous",
    "media.play-pause": "play",
    "media.play-pause-locked": "play",
    "media.stop-locked": "stop",
    "system.calculator": "calculator",
    "system.lock": "lock",
    "system.lock-locked": "lock",
    "system.dpms-off": "moon",
    "system.dpms-on": "sun",
    "utilities.routine": "flowArrow",
    "utilities.timer": "timer",
    "window.close": "xCircle",
    "window.drag": "handGrab",
    "window.focus": "cursor",
    "window.fullscreen": "arrowsOut",
    "window.maximize": "cornersOut",
    "window.move": "arrowsOutCardinal",
    "window.resize": "arrowsOutSimple",
    "window.resize-drag": "arrowsOutSimple",
    "window.toggle-float": "stack",
    "workspace.switch": "squaresFour",
    "workspace.switch-occupied": "squaresFour",
    "workspace.switch-relative": "squaresFour",
    "workspace.toggle-special": "stack",
    "workspace.toggle-special-named": "stack"
};

// raw compositor dispatchers (legacy.dispatcher)
var DISPATCHER = {
    "exec": "terminalWindow",
    "execr": "terminalWindow",
    "killactive": "xCircle",
    "fullscreen": "arrowsOut",
    "fullscreenstate": "arrowsOut",
    "togglefloating": "stack",
    "movefocus": "cursor",
    "movewindow": "arrowsOutCardinal",
    "resizeactive": "arrowsOutSimple",
    "workspace": "squaresFour",
    "movetoworkspace": "squaresFour",
    "movetoworkspacesilent": "squaresFour",
    "togglespecialworkspace": "stack",
    "pseudo": "columns",
    "togglesplit": "columns",
    "pin": "pin",
    "exit": "xCircle"
};

// a command line (command.run, an exec dispatcher), by what it runs
var COMMANDS = [
    [/maximi[sz]e/, "cornersOut"],
    [/fullscreen/, "arrowsOut"],
    [/float/, "stack"],
    [/\b(firefox|chromium|chrome|brave|librewolf|zen|vivaldi|qutebrowser|epiphany)\b/, "globe"],
    [/\b(nautilus|thunar|dolphin|nemo|pcmanfm|caja|yazi|ranger|lf|nnn)\b/, "folder"],
    [/\b(kitty|alacritty|foot|wezterm|ghostty|konsole|xterm|st)\b/, "terminal"],
    [/\b(grim|slurp|hyprshot|flameshot|grimblast|screenshot)\b/, "camera"],
    [/\b(cliphist|clipman|wl-copy|wl-paste)\b/, "clipboard"],
    [/(record|replay|clip|wf-recorder|\bobs\b)/, "recordScreen"],
    [/\bplayerctl\b/, "musicNotes"],
    [/\b(wpctl|pamixer|pactl|amixer)\b/, "speakerHigh"],
    [/\b(brightnessctl|light)\b/, "sun"],
    [/\b(code|codium|nvim|vim|emacs|zed)\b/, "code"],
    [/\b(lock|swaylock|hyprlock)\b/, "lock"]
];

function commandIcon(cmd) {
    var c = String(cmd || "").toLowerCase();
    for (var i = 0; c && i < COMMANDS.length; i++) {
        if (COMMANDS[i][0].test(c))
            return COMMANDS[i][1];
    }
    return "terminalWindow";
}

// a prefix of a catalog id the tables above do not name yet
var PREFIX = [["window.", "appWindow"], ["workspace.", "squaresFour"], ["media.", "musicNotes"], ["audio.", "speakerHigh"], ["brightness.", "sun"], ["scrolling.", "scrolling"], ["monocle.", "monocle"], ["system.", "monitor"], ["utilities.", "toolbox"]];

function has(table, key) {
    return Object.prototype.hasOwnProperty.call(table, key);
}

function forAction(action, groupIcon) {
    var id = action ? BrandActions.normalizeAction(String(action.id || "")) : "";
    var own = BrandActions.appId + ".";
    if (id.indexOf(own) === 0) {
        var name = id.substring(own.length);
        return has(APP, name) ? APP[name] : (groupIcon || "widgets");
    }
    if (id === "command.run")
        return commandIcon(action.args && action.args.command);
    if (id === "legacy.dispatcher") {
        var d = String((action.args && action.args.dispatcher) || "").trim().toLowerCase();
        if (d === "exec" || d === "execr")
            return commandIcon(action.args.argument);
        return has(DISPATCHER, d) ? DISPATCHER[d] : (groupIcon || "code");
    }
    if (has(CATALOG, id))
        return CATALOG[id];
    for (var i = 0; i < PREFIX.length; i++) {
        if (id.indexOf(PREFIX[i][0]) === 0)
            return PREFIX[i][1];
    }
    return groupIcon || "command";
}

function forBind(bind, groupIcon) {
    var actions = bind && bind.actions ? bind.actions : [];
    return forAction(actions.length > 0 ? actions[0] : null, groupIcon);
}
