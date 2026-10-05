import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "../Commands.js" as Commands

// Shell commands ("> preset Neon Tokyo", "> dnd", "> random wallpaper",
// "> glass 0.6") from the shared registry assets/commands/commands.json
// (also behind `<app> cmd` and the MCP shell_command tool). In mixed
// searches only strong matches show ("dnd", "keybinds").
LauncherProvider {
    id: cmds

    mixedLimit: 2

    property var registry: []
    readonly property var presetNames: (PresetsService.presets || []).map(p => p.name)

    property FileView file: FileView {
        path: Qt.resolvedUrl("../../../../assets/commands/commands.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: {
            try {
                cmds.registry = JSON.parse(cmds.file.text()).commands || [];
            } catch (e) {
                console.warn("launcher: bad commands registry", e);
                cmds.registry = [];
            }
            if (cmds.mode !== "")
                cmds.search(cmds.query, cmds.mode);
        }
    }

    onPresetNamesChanged: {
        if (cmds.mode !== "" && cmds.query !== "")
            cmds.search(cmds.query, cmds.mode);
    }

    function labelled() {
        return cmds.registry.map(c => Object.assign({
                "label": I18n.t(c.title)
            }, c));
    }

    function compute(text, searchMode) {
        if (cmds.registry.length === 0)
            return [];
        if (/^\s*preset\b/i.test(text) && cmds.presetNames.length === 0)
            PresetsService.scanPresets();
        const rows = Commands.match(cmds.labelled(), text, cmds.presetNames, searchMode !== "prefix");
        return rows.map(r => cmds.row(r));
    }

    function argText(cmd) {
        const a = cmd.arg;
        if (!a)
            return "";
        if (a.kind === "number")
            return a.min + "–" + a.max;
        if (a.kind === "enum")
            return (a.values || []).join(" | ");
        return I18n.t("launcher.cmd.arg." + a.kind);
    }

    function row(r) {
        const c = r.cmd;
        const shown = r.arg;
        let sub = I18n.t(c.description);
        if (!r.check.ok)
            sub = I18n.t("launcher.cmd.error." + (r.check.error || "missing")).replace("%1", cmds.argText(c));
        return {
            "key": c.id + ":" + r.arg,
            "title": c.label + (shown ? "  ·  " + shown : ""),
            "subtitle": sub,
            "icon": Icons[c.icon] || Icons.command,
            "badge": (cmds.host ? cmds.host.prefixFor("commands") : ">") + " " + c.id,
            "hint": r.check.ok ? I18n.t("launcher.run") : I18n.t("launcher.complete"),
            "data": {
                "cmd": c,
                "arg": r.arg,
                "check": r.check
            }
        };
    }

    function completion(item) {
        if (!item || !item.data)
            return "";
        const c = item.data.cmd;
        if (!c.arg || item.data.check.ok)
            return "";
        return Commands.completion(cmds.host ? cmds.host.prefixFor("commands") : ">", c, "");
    }

    function activate(item, option) {
        const d = item.data;
        if (!d)
            return false;
        if (!d.check.ok) {
            if (cmds.host)
                cmds.host.setSearch(cmds.completion(item) || Commands.completion(cmds.host.prefixFor("commands"), d.cmd, d.arg));
            return false;
        }
        cmds.execute(Commands.plan(d.cmd, d.check.value));
        return true;
    }

    function execute(plan) {
        if (!plan)
            return;
        if (plan.kind === "ui")
            Qt.callLater(() => GlobalShortcuts.run(plan.value));
        else if (plan.kind === "toggle")
            Qt.callLater(() => GlobalShortcuts.toggle(plan.value));
        else if (plan.kind === "cli")
            Quickshell.execDetached([Brand.appId].concat(plan.argv));
        else if (plan.kind === "config")
            Quickshell.execDetached([Brand.appId, "config", "set", plan.key, String(plan.value)]);
    }
}
