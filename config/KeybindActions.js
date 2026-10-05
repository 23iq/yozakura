.pragma library
.import "../modules/globals/BrandActions.js" as BrandActions

function clone(obj) {
    return JSON.parse(JSON.stringify(obj || {}));
}

function formatOffset(value) {
    if (value === undefined || value === null || value === "") {
        return "0";
    }
    const raw = String(value).trim();
    if (raw.startsWith("+") || raw.startsWith("-")) {
        return raw;
    }
    const num = parseInt(raw, 10);
    if (isNaN(num)) {
        return raw;
    }
    return num >= 0 ? "+" + num : String(num);
}

function directionToLetter(direction) {
    const dir = String(direction || "").toLowerCase();
    if (dir === "up" || dir === "u") return "u";
    if (dir === "down" || dir === "d") return "d";
    if (dir === "left" || dir === "l") return "l";
    if (dir === "right" || dir === "r") return "r";
    return "";
}

var ACTION_CATALOG = [
    { id: BrandActions.action("launcher"), label: "Open Launcher", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "launcher"), flags: "r" },
    { id: BrandActions.action("dashboard"), label: "Open Dashboard", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "dashboard") },
    { id: BrandActions.action("assistant"), label: "Open Assistant", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "assistant") },
    { id: BrandActions.action("ai-quickask"), label: "AI Quick Ask (notch)", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "ai-quickask") },
    { id: BrandActions.action("ai-selection"), label: "AI Selection Actions", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "ai-selection") },
    { id: BrandActions.action("ai-region"), label: "AI Ask About Screen Region", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "ai-region") },
    { id: BrandActions.action("ai-agent"), label: "AI Agent Mode", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "ai-agent") },
    { id: BrandActions.action("ai-shell"), label: "AI Shell Control", category: BrandActions.displayName, group: "ai", dispatcher: "exec", argument: BrandActions.command("run", "ai-shell") },
    { id: BrandActions.action("dnd-toggle"), label: "Toggle Do Not Disturb", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "dnd-toggle") },
    { id: BrandActions.action("clipboard"), label: "Open Clipboard", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "clipboard") },
    { id: BrandActions.action("emoji"), label: "Open Emoji", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "emoji") },
    { id: BrandActions.action("notes"), label: "Open Notes", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "notes") },
    { id: BrandActions.action("tmux"), label: "Open Tmux", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "tmux") },
    { id: BrandActions.action("terminal"), label: "Open Terminal", category: BrandActions.displayName, group: "apps", dispatcher: "exec", argument: BrandActions.command("run", "terminal") },
    { id: BrandActions.action("wallpapers"), label: "Open Wallpapers", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "wallpapers") },
    { id: BrandActions.action("config"), label: "Open Settings", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "config") },
    { id: BrandActions.action("overview"), label: "Open Overview", category: BrandActions.displayName, group: "workspaces", dispatcher: "exec", argument: BrandActions.command("run", "overview") },
    { id: BrandActions.action("bar"), label: "Toggle Bar", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("toggle", "bar") },
    { id: BrandActions.action("powermenu"), label: "Open Power Menu", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "powermenu") },
    { id: BrandActions.action("tools"), label: "Open Tools", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "tools") },
    { id: BrandActions.action("screenshot"), label: "Take Screenshot", category: BrandActions.displayName, group: "screenshots", dispatcher: "exec", argument: BrandActions.command("run", "screenshot") },
    { id: BrandActions.action("screenrecord"), label: "Screen Record", category: BrandActions.displayName, group: "screenshots", dispatcher: "exec", argument: BrandActions.command("run", "screenrecord") },
    { id: BrandActions.action("lens"), label: "Open Lens", category: BrandActions.displayName, group: "screenshots", dispatcher: "exec", argument: BrandActions.command("run", "lens") },
    { id: BrandActions.action("reload"), label: "Reload " + BrandActions.displayName, category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("reload") },
    { id: BrandActions.action("quit"), label: "Quit " + BrandActions.displayName, category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("quit") },
    { id: BrandActions.action("keybinds"), label: "Show Keybinds", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "keybinds") },
    { id: BrandActions.action("desktop-edit"), label: "Edit Desktop Widgets", category: BrandActions.displayName, group: "shell", dispatcher: "exec", argument: BrandActions.command("run", "desktop-edit") },
    // Hold actions: the TOML renderer adds a release bind running
    // `yozakura voice release` (backend/pkg/svc/compositor/holdbinds.go).
    { id: BrandActions.action("voice-ai"), label: "Voice to AI (hold)", category: BrandActions.displayName, group: "ai", hold: true, dispatcher: "exec", argument: BrandActions.command("voice", "press", "ai") },
    { id: BrandActions.action("dictation"), label: "Dictation (hold)", category: BrandActions.displayName, group: "ai", hold: true, dispatcher: "exec", argument: BrandActions.command("voice", "press", "dictation") },

    { id: "window.close", label: "Close Window", category: "Window", group: "windows", dispatcher: "killactive", argument: "" },
    { id: "window.focus", label: "Focus Window", category: "Window", group: "windows", dispatcher: "movefocus", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "up" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "window.move", label: "Move Window", category: "Window", group: "windows", dispatcher: "movewindow", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "window.drag", label: "Drag Window", category: "Window", group: "windows", dispatcher: "movewindow", argument: "", flags: "m" },
    { id: "window.resize-drag", label: "Resize Window (Drag)", category: "Window", group: "windows", dispatcher: "resizewindow", argument: "", flags: "m" },
    { id: "window.resize", label: "Resize Window", category: "Window", group: "windows", dispatcher: "resizeactive", args: [{ key: "delta", label: "Delta", placeholder: "50 0", defaultValue: "50 0" }], argumentBuilder: function (args) {
        return String(args.delta || "").trim();
    } },
    { id: "window.toggle-float", label: "Toggle Floating", category: "Window", group: "windows", dispatcher: "togglefloating", argument: "" },

    { id: "workspace.switch", label: "Switch Workspace", category: "Workspace", group: "workspaces", dispatcher: "workspace", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.switch-relative", label: "Switch Workspace (Relative)", category: "Workspace", group: "workspaces", dispatcher: "workspace", args: [{ key: "offset", label: "Offset", placeholder: "+1 / -1", defaultValue: "+1" }], argumentBuilder: function (args) {
        return formatOffset(args.offset);
    } },
    { id: "workspace.switch-occupied", label: "Switch Occupied Workspace", category: "Workspace", group: "workspaces", dispatcher: "workspace", args: [{ key: "offset", label: "Offset", placeholder: "+1 / -1", defaultValue: "+1" }], argumentBuilder: function (args) {
        const offset = formatOffset(args.offset);
        return "e" + offset;
    } },
    { id: "workspace.move-window", label: "Move Window to Workspace", category: "Workspace", group: "workspaces", dispatcher: "movetoworkspace", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.move-window-silent", label: "Move Window to Workspace (Silent)", category: "Workspace", group: "workspaces", dispatcher: "movetoworkspacesilent", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return String(args.index || "").trim();
    } },
    { id: "workspace.toggle-special", label: "Toggle Special Workspace", category: "Workspace", group: "workspaces", dispatcher: "togglespecialworkspace", argument: "" },
    { id: "workspace.move-window-special", label: "Move Window to Special Workspace", category: "Workspace", group: "workspaces", dispatcher: "movetoworkspace", argument: "special" },
    { id: "workspace.move-window-special-silent", label: "Move Window to Special Workspace (Silent)", category: "Workspace", group: "workspaces", dispatcher: "movetoworkspacesilent", argument: "special" },
    // Named special workspaces (modules/specials): toggle one / send the
    // active window there without following it.
    { id: "workspace.toggle-special-named", label: "Toggle Named Special Workspace", category: "Workspace", group: "workspaces", dispatcher: "togglespecialworkspace", args: [{ key: "name", label: "Name", placeholder: "Telegram", defaultValue: "" }], argumentBuilder: function (args) {
        return String(args.name || "").trim();
    } },
    { id: "workspace.move-window-special-named", label: "Send Window to Named Special Workspace", category: "Workspace", group: "workspaces", dispatcher: "movetoworkspacesilent", args: [{ key: "name", label: "Name", placeholder: "Telegram", defaultValue: "" }], argumentBuilder: function (args) {
        return "special:" + String(args.name || "").trim();
    } },

    { id: "scrolling.focus", label: "Focus", category: "Window", group: "windows", dispatcher: "movefocus", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "up" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "scrolling.move-window", label: "Move Window", category: "Window", group: "windows", dispatcher: "movewindow", args: [{ key: "direction", label: "Direction", placeholder: "up/down/left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return directionToLetter(args.direction);
    } },
    { id: "monocle.focus", label: "Cycle Focus", category: "Monocle Layout", group: "windows", dispatcher: "cyclenext", args: [{ key: "direction", label: "Direction", placeholder: "up/right = next, down/left = prev", defaultValue: "next" }], argumentBuilder: function (args) {
        return (args.direction === "d" || args.direction === "l") ? "cycleprev" : "cyclenext";
    } },
    { id: "monocle.move-window", label: "Cycle Window", category: "Monocle Layout", group: "windows", dispatcher: "cyclenext", args: [{ key: "direction", label: "Direction", placeholder: "up/right = next, down/left = prev", defaultValue: "next" }], argumentBuilder: function (args) {
        return (args.direction === "d" || args.direction === "l") ? "cycleprev" : "cyclenext";
    } },
    { id: "scrolling.resize-column", label: "Resize Column", category: "Scrolling Layout", group: "windows", dispatcher: "layoutmsg", args: [{ key: "delta", label: "Delta", placeholder: "+0.1 / -0.1", defaultValue: "+0.1" }], argumentBuilder: function (args) {
        return "colresize " + String(args.delta || "").trim();
    } },
    { id: "scrolling.promote", label: "Promote Column", category: "Scrolling Layout", group: "windows", dispatcher: "layoutmsg", argument: "promote" },
    { id: "scrolling.toggle-fit", label: "Toggle Fit", category: "Scrolling Layout", group: "windows", dispatcher: "layoutmsg", argument: "togglefit" },
    { id: "scrolling.toggle-full-column", label: "Toggle Full Column", category: "Scrolling Layout", group: "windows", dispatcher: "layoutmsg", argument: "colresize +conf" },
    { id: "scrolling.swap-column", label: "Swap Column", category: "Scrolling Layout", group: "windows", dispatcher: "layoutmsg", args: [{ key: "direction", label: "Direction", placeholder: "left/right", defaultValue: "left" }], argumentBuilder: function (args) {
        return "swapcol " + directionToLetter(args.direction);
    } },
    { id: "scrolling.move-column-workspace", label: "Move Column to Workspace", category: "Scrolling Layout", group: "workspaces", dispatcher: "layoutmsg", args: [{ key: "index", label: "Workspace", placeholder: "1", defaultValue: "1" }], argumentBuilder: function (args) {
        return "movecoltoworkspace " + String(args.index || "").trim();
    } },

    { id: "media.play-pause", label: "Play/Pause", category: "Media", group: "media", dispatcher: "exec", argument: "playerctl play-pause" },
    { id: "media.play-pause-locked", label: "Play/Pause (Locked)", category: "Media", group: "media", dispatcher: "exec", argument: "playerctl play-pause", flags: "l" },
    { id: "media.prev", label: "Previous Track", category: "Media", group: "media", dispatcher: "exec", argument: "playerctl previous" },
    { id: "media.next", label: "Next Track", category: "Media", group: "media", dispatcher: "exec", argument: "playerctl next" },
    { id: "media.stop-locked", label: "Stop Playback (Locked)", category: "Media", group: "media", dispatcher: "exec", argument: "playerctl stop", flags: "l" },

    { id: "audio.volume-up", label: "Volume Up", category: "Audio", group: "media", dispatcher: "exec", argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+", flags: "le" },
    { id: "audio.volume-down", label: "Volume Down", category: "Audio", group: "media", dispatcher: "exec", argument: "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-", flags: "le" },
    { id: "audio.mute-toggle", label: "Mute Audio", category: "Audio", group: "media", dispatcher: "exec", argument: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", flags: "le" },

    { id: "brightness.up", label: "Brightness Up", category: "Brightness", group: "media", dispatcher: "exec", argument: "sh -c 'echo brightness-up > \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/" + BrandActions.appId + "_ipc.pipe\"'", flags: "le" },
    { id: "brightness.down", label: "Brightness Down", category: "Brightness", group: "media", dispatcher: "exec", argument: "sh -c 'echo brightness-down > \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/" + BrandActions.appId + "_ipc.pipe\"'", flags: "le" },

    { id: "system.calculator", label: "Calculator", category: "System", group: "system", dispatcher: "exec", argument: "notify-send \"Soon\"" },
    { id: "system.lock", label: "Lock Session", category: "System", group: "system", dispatcher: "exec", argument: "loginctl lock-session" },
    { id: "system.lock-locked", label: "Lock Session (Locked)", category: "System", group: "system", dispatcher: "exec", argument: "loginctl lock-session", flags: "l" },
    { id: "system.dpms-off", label: "Display Off", category: "System", group: "system", dispatcher: "exec", argument: BrandActions.daemonCommand("monitor", "set-dpms", "0", "0"), flags: "l" },
    { id: "system.dpms-on", label: "Display On", category: "System", group: "system", dispatcher: "exec", argument: BrandActions.daemonCommand("monitor", "set-dpms", "0", "1"), flags: "l" },

    { id: "command.run", label: "Run Command", category: "Custom", group: "apps", dispatcher: "exec", args: [{ key: "command", label: "Command", placeholder: "command to run", defaultValue: "" }], argumentBuilder: function (args) {
        return String(args.command || "").trim();
    } },

    { id: "legacy.dispatcher", label: "Legacy Dispatcher", category: "Advanced", group: "apps", dispatcher: "", args: [
        { key: "dispatcher", label: "Dispatcher", placeholder: "dispatcher", defaultValue: "" },
        { key: "argument", label: "Argument", placeholder: "argument", defaultValue: "" },
        { key: "flags", label: "Flags", placeholder: "flags", defaultValue: "" }
    ], hidden: true }
];

var ACTION_INDEX = {};
for (var i = 0; i < ACTION_CATALOG.length; i++) {
    ACTION_INDEX[ACTION_CATALOG[i].id] = ACTION_CATALOG[i];
}

function getActionById(id) {
    return ACTION_INDEX[BrandActions.normalizeAction(id)] || null;
}

function getActionOptions() {
    return ACTION_CATALOG.filter(a => !a.hidden).map(a => ({
        id: a.id,
        label: a.label,
        category: a.category,
        group: a.group
    }));
}

// Translation key of an action label: "binds.action.<id>", with the app's
// own actions under "binds.action.app.<name>" (ids carry the app id).
function labelKey(id) {
    const norm = BrandActions.normalizeAction(id || "");
    const prefix = BrandActions.appId + ".";
    if (norm.indexOf(prefix) === 0)
        return "binds.action.app." + norm.substring(prefix.length);
    return "binds.action." + norm;
}

// Cheatsheet/editor group of an action ("apps" for unknown ids).
function groupOf(id) {
    const entry = getActionById(id);
    return entry && entry.group ? entry.group : "apps";
}

// Translation key of an action argument field: "binds.field.<key>".
function fieldLabelKey(key) {
    return "binds.field." + key;
}

function getActionFields(actionId) {
    const action = getActionById(actionId);
    if (!action || !action.args) return [];
    return action.args.map(field => ({
        key: field.key,
        label: field.label,
        placeholder: field.placeholder || "",
        defaultValue: field.defaultValue !== undefined ? field.defaultValue : ""
    }));
}

function defaultArgs(actionId) {
    const fields = getActionFields(actionId);
    let args = {};
    for (var i = 0; i < fields.length; i++) {
        args[fields[i].key] = fields[i].defaultValue;
    }
    return args;
}

function resolveAction(action) {
    if (!action) return null;
    if (action.dispatcher) {
        return {
            dispatcher: action.dispatcher || "",
            argument: action.argument || "",
            flags: action.flags || ""
        };
    }
    const entry = getActionById(action.id);
    if (!entry) return null;

    let argument = entry.argument || "";
    if (entry.argumentBuilder) {
        argument = entry.argumentBuilder(action.args || {});
    }
    if (entry.id === "legacy.dispatcher") {
        return {
            dispatcher: (action.args && action.args.dispatcher) || "",
            argument: (action.args && action.args.argument) || "",
            flags: (action.args && action.args.flags) || ""
        };
    }

    return {
        dispatcher: entry.dispatcher || "",
        argument: argument || "",
        flags: entry.flags || ""
    };
}

function describeAction(action) {
    if (!action) return "";
    const entry = getActionById(action.id);
    if (!entry) return "";
    if (entry.id === "legacy.dispatcher") {
        const dispatcher = action.args && action.args.dispatcher ? action.args.dispatcher : "";
        const argument = action.args && action.args.argument ? action.args.argument : "";
        return dispatcher + (argument ? " " + argument : "");
    }
    const fields = getActionFields(action.id);
    if (fields.length === 0) {
        return entry.label;
    }
    const args = action.args || {};
    const details = fields.map(f => args[f.key]).filter(v => v !== undefined && v !== "").join(" ");
    return details ? entry.label + " · " + details : entry.label;
}

function ensureAction(action) {
    if (!action) return null;
    if (action.id) {
        const fixed = clone(action);
        fixed.id = BrandActions.normalizeAction(fixed.id);
        if (!fixed.args) {
            fixed.args = defaultArgs(fixed.id);
        }
        return fixed;
    }
    if (action.dispatcher) {
        return actionFromLegacy(action.dispatcher, action.argument || "", action.flags || "");
    }
    return null;
}

function actionFromLegacy(dispatcher, argument, flags) {
    const arg = String(argument || "").trim();
    // "<app> run <name>" / "<legacy> run <name>" from old binds.
    const run = /^(\S+) (run|toggle) (\S+)$/.exec(arg);
    if (dispatcher === "exec" && run && (run[1] === BrandActions.appId || run[1] === BrandActions.legacyAppId)) {
        const id = BrandActions.action(run[3]);
        if (ACTION_INDEX[id]) return { id: id, args: {} };
    }
    if (dispatcher === "killactive") return { id: "window.close", args: {} };
    if (dispatcher === "workspace") {
        if (arg.startsWith("e")) {
            return { id: "workspace.switch-occupied", args: { offset: arg.substring(1) } };
        }
        if (arg.startsWith("+") || arg.startsWith("-")) {
            return { id: "workspace.switch-relative", args: { offset: arg } };
        }
        return { id: "workspace.switch", args: { index: arg } };
    }
    if (dispatcher === "movetoworkspace") {
        if (arg === "special") return { id: "workspace.move-window-special", args: {} };
        return { id: "workspace.move-window", args: { index: arg } };
    }
    if (dispatcher === "movetoworkspacesilent") {
        if (arg === "special") return { id: "workspace.move-window-special-silent", args: {} };
        if (arg.indexOf("special:") === 0) return { id: "workspace.move-window-special-named", args: { name: arg.substring(8) } };
        return { id: "workspace.move-window-silent", args: { index: arg } };
    }
    if (dispatcher === "togglespecialworkspace") return arg ? { id: "workspace.toggle-special-named", args: { name: arg } } : { id: "workspace.toggle-special", args: {} };
    if (dispatcher === "movewindow" && flags === "m") return { id: "window.drag", args: {} };
    if (dispatcher === "resizewindow" && flags === "m") return { id: "window.resize-drag", args: {} };
    if (dispatcher === "movewindow") return { id: "window.move", args: { direction: arg } };
    if (dispatcher === "movefocus") return { id: "window.focus", args: { direction: arg } };
    if (dispatcher === "resizeactive") return { id: "window.resize", args: { delta: arg } };
    if (dispatcher === "togglefloating") return { id: "window.toggle-float", args: {} };
    if (dispatcher === "layoutmsg") {
        if (arg.startsWith("focus ")) return { id: "scrolling.focus", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("movewindowto ")) return { id: "scrolling.move-window", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("colresize ")) {
            const delta = arg.split(" ")[1] || "";
            if (delta === "+conf") return { id: "scrolling.toggle-full-column", args: {} };
            return { id: "scrolling.resize-column", args: { delta: delta } };
        }
        if (arg === "promote") return { id: "scrolling.promote", args: {} };
        if (arg === "togglefit") return { id: "scrolling.toggle-fit", args: {} };
        if (arg.startsWith("swapcol ")) return { id: "scrolling.swap-column", args: { direction: arg.split(" ")[1] } };
        if (arg.startsWith("movecoltoworkspace ")) return { id: "scrolling.move-column-workspace", args: { index: arg.split(" ")[1] } };
    }
    if (dispatcher === "exec") {
        if (arg === "playerctl play-pause" && flags === "l") return { id: "media.play-pause-locked", args: {} };
        if (arg === "playerctl play-pause") return { id: "media.play-pause", args: {} };
        if (arg === "playerctl previous") return { id: "media.prev", args: {} };
        if (arg === "playerctl next") return { id: "media.next", args: {} };
        if (arg === "playerctl stop" && flags === "l") return { id: "media.stop-locked", args: {} };
        if (arg.indexOf("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+") === 0) return { id: "audio.volume-up", args: {} };
        if (arg.indexOf("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%-") === 0) return { id: "audio.volume-down", args: {} };
        if (arg.indexOf("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") === 0) return { id: "audio.mute-toggle", args: {} };
        if (arg.indexOf(BrandActions.command("brightness", "+5")) === 0 || arg.indexOf(BrandActions.legacyAppId + " brightness +5") === 0) return { id: "brightness.up", args: {} };
        if (arg.indexOf(BrandActions.command("brightness", "-5")) === 0 || arg.indexOf(BrandActions.legacyAppId + " brightness -5") === 0) return { id: "brightness.down", args: {} };
        if (arg === "notify-send \"Soon\"") return { id: "system.calculator", args: {} };
        if (arg === "loginctl lock-session" && flags === "l") return { id: "system.lock-locked", args: {} };
        if (arg === "loginctl lock-session") return { id: "system.lock", args: {} };
        if (arg === BrandActions.daemonCommand("monitor", "set-dpms", "0", "0") || arg === BrandActions.legacyDaemon + " monitor set-dpms 0 0") return { id: "system.dpms-off", args: {} };
        if (arg === BrandActions.daemonCommand("monitor", "set-dpms", "0", "1") || arg === BrandActions.legacyDaemon + " monitor set-dpms 0 1") return { id: "system.dpms-on", args: {} };
        return { id: "command.run", args: { command: arg } };
    }

    return {
        id: "legacy.dispatcher",
        args: {
            dispatcher: dispatcher || "",
            argument: arg,
            flags: flags || ""
        }
    };
}

function normalizeCustomBinds(binds) {
    let changed = false;
    let normalized = [];

    for (var i = 0; i < binds.length; i++) {
        const bind = binds[i] || {};

        if (bind.keys === undefined || bind.actions === undefined) {
            changed = true;
            normalized.push({
                name: bind.name || "",
                keys: [
                    {
                        modifiers: bind.modifiers || [],
                        key: bind.key || ""
                    }
                ],
                actions: [
                    Object.assign({ layouts: [] }, actionFromLegacy(bind.dispatcher || "", bind.argument || "", bind.flags || ""))
                ],
                enabled: bind.enabled !== false
            });
            continue;
        }

        let actions = [];
        let actionChanged = false;
        for (var a = 0; a < bind.actions.length; a++) {
            let action = bind.actions[a] || {};
            if (action.dispatcher) {
                actionChanged = true;
                const mapped = actionFromLegacy(action.dispatcher || "", action.argument || "", action.flags || "");
                mapped.layouts = action.layouts || [];
                actions.push(mapped);
            } else if (!action.id) {
                actionChanged = true;
                actions.push(Object.assign({ layouts: action.layouts || [] }, actionFromLegacy("", "", "")));
            } else {
                const fixed = ensureAction(action);
                fixed.layouts = action.layouts || [];
                actions.push(fixed);
            }
        }

        if (actionChanged) changed = true;
        normalized.push({
            name: bind.name || "",
            keys: bind.keys || [],
            actions: actions,
            enabled: bind.enabled !== false
        });
    }

    return { changed: changed, binds: normalized };
}

function migrateLegacyCustomBinds(binds) {
    return normalizeCustomBinds(binds).binds;
}
