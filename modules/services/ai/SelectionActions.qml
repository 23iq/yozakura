import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import "Templates.js" as Templates
import "SafeText.js" as SafeText
import "../../aicenter/lib/Markdown.js" as Markdown

// Selection actions: a bind opens a menu near the cursor with actions for the
// primary selection (translate, explain, rewrite, fix code, prompt library).
// The result replaces the selection (wtype), goes to the clipboard or opens
// in the sidebar, per action.
QtObject {
    id: root

    property bool visible: false
    property string text: ""
    property string screenName: ""
    property point cursor: Qt.point(-1, -1)
    property bool working: false
    property string workingLabel: ""
    property string error: ""

    // [{id, label, icon, prompt, output, kind: action|prompt}]
    readonly property var actions: {
        const out = [];
        for (const a of Config.ai.selection.actions || [])
            if (a && a.prompt)
                out.push({
                    id: a.id,
                    label: a.label || I18n.t("ai.action_" + a.id),
                    icon: a.icon || "sparkle",
                    prompt: a.prompt,
                    output: a.output || Config.ai.selection.output,
                    kind: "action"
                });
        for (const p of Config.ai.prompts || [])
            if (p && p.prompt && Templates.variables(p.prompt).indexOf("selection") >= 0)
                out.push({
                    id: "prompt:" + p.id,
                    label: p.name || p.id,
                    icon: "scroll",
                    prompt: p.prompt,
                    output: p.output === "notify" ? "sidebar" : (p.output || "sidebar"),
                    kind: "prompt"
                });
        return out;
    }

    function open() {
        error = "";
        working = false;
        screenName = GlobalStates.focusedScreenName();
        reader.running = true;
    }

    function close() {
        visible = false;
        working = false;
    }

    property Process reader: Process {
        command: ["sh", "-c", "wl-paste -p -n 2>/dev/null; printf '\\n\\x1e'; hyprctl cursorpos 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n\x1e");
                root.text = (parts[0] || "").replace(/\n$/, "");
                const pos = (parts[1] || "").trim().split(",").map(v => parseInt(v, 10));
                root.cursor = pos.length === 2 && !isNaN(pos[0]) ? Qt.point(pos[0], pos[1]) : Qt.point(-1, -1);
                if (!root.text.trim()) {
                    notifier.command = ["notify-send", "-a", "Yozakura AI", I18n.t("ai.selection_empty_title"), I18n.t("ai.selection_empty_body")];
                    notifier.running = true;
                    return;
                }
                root.visible = true;
            }
        }
    }

    property Process notifier: Process {}

    // Free-form instruction applied to the selection ("Ask…" field).
    function ask(instruction) {
        if (!instruction.trim())
            return;
        const att = {
            type: "text",
            kind: "selection",
            name: "selection",
            text: text
        };
        close();
        Ai.askQuick(instruction, [att]);
    }

    function run(action) {
        const prompt = Templates.expand(action.prompt, {
            selection: text,
            language: Config.ai.selection.language
        });
        if (action.output === "sidebar") {
            close();
            Ai.setMode("chat");
            if (!GlobalStates.assistantVisible)
                GlobalStates.toggleAssistant();
            Ai.send(prompt, []);
            return;
        }
        if (action.output === "quickask") {
            close();
            Ai.askQuick(prompt, []);
            return;
        }
        working = true;
        workingLabel = action.label;
        Ai.runPrompt(prompt, {}, (result, err) => {
            working = false;
            if (err) {
                error = err;
                return;
            }
            const clean = _unfence(result);
            visible = false;
            const typed = SafeText.forTyping(clean);
            if (action.output === "clipboard") {
                output.command = ["wl-copy", "--", clean];
            } else if (typed.multiline) {
                // Typing a line break into a terminal would run it: copy
                // instead and let the user paste.
                output.command = ["sh", "-c", "printf %s \"$1\" | wl-copy && notify-send -a \"$2\" -- \"$3\" \"$4\"", "sh", clean, Brand.displayName, I18n.t("ai.selection_multiline_title"), I18n.t("ai.selection_multiline_body")];
            } else {
                // Give focus back to the app, then type over the still-selected text.
                output.command = ["sh", "-c", "sleep 0.15; if [ ${#1} -le 4000 ]; then wtype -- \"$1\"; else printf %s \"$1\" | wl-copy && wtype -M ctrl v -m ctrl; fi", "sh", typed.text];
            }
            output.running = true;
        });
    }

    // Models sometimes wrap a code answer in a fence despite instructions.
    function _unfence(s) {
        const segs = Markdown.segments(s);
        if (segs.length === 1 && segs[0].type === "code")
            return segs[0].content;
        return String(s).trim();
    }

    property Process output: Process {}
}
