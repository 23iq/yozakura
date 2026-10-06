import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import "Templates.js" as Templates
import "../../aicenter/lib/Markdown.js" as Markdown

// Selection actions: a bind opens a menu near the cursor with actions for the
// primary selection (translate, explain, rewrite, fix code, prompt library).
// Results remain in a preview until explicitly copied or opened in the
// workspace. No focus-dependent typing is safe without verifying the target.
QtObject {
    id: root

    property bool visible: false
    property string text: ""
    property string screenName: ""
    property point cursor: Qt.point(-1, -1)
    property bool working: false
    property string workingLabel: ""
    property string error: ""
    property string result: ""
    property bool hasResult: false
    property int _generation: 0

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
        _generation++;
        error = "";
        result = "";
        hasResult = false;
        working = false;
        screenName = GlobalStates.focusedScreenName();
        reader.running = true;
    }

    function close() {
        _generation++;
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
                    root.notifier.command = ["notify-send", "-a", Brand.displayName, I18n.t("ai.selection_empty_title"), I18n.t("ai.selection_empty_body")];
                    root.notifier.running = true;
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
        return _finishShortcut(Ai.askQuick(instruction, [att]));
    }

    function _finishShortcut(accepted) {
        if (accepted) {
            close();
            return true;
        }
        error = Ai.noticeError || I18n.t("ai.engine_unavailable");
        return false;
    }

    function copyResult() {
        if (!hasResult)
            return;
        error = "";
        output.command = ["wl-copy", "--", result];
        output.running = true;
    }

    function openResult() {
        if (!hasResult)
            return false;
        if (!GlobalStates.assistantVisible)
            GlobalStates.toggleAssistant();
        // Continue with both the source and result available for inspection.
        return _finishShortcut(Ai.send(result, [
            {
                type: "text",
                kind: "selection",
                name: "selection",
                text: text
            }
        ]));
    }

    function run(action) {
        if (working)
            return;
        const prompt = Templates.expand(action.prompt, {
            selection: text,
            language: Config.ai.selection.language
        });
        error = "";
        result = "";
        hasResult = false;
        if (action.output === "sidebar") {
            if (!GlobalStates.assistantVisible)
                GlobalStates.toggleAssistant();
            _finishShortcut(Ai.send(prompt, []));
            return;
        }
        if (action.output === "quickask") {
            _finishShortcut(Ai.askQuick(prompt, []));
            return;
        }
        working = true;
        workingLabel = action.label;
        const generation = ++_generation;
        Ai.runPrompt(prompt, {}, (answer, err) => {
            if (generation !== _generation)
                return;
            working = false;
            if (err) {
                error = err;
                return;
            }
            result = _unfence(answer);
            hasResult = true;
        });
    }

    // Models sometimes wrap a code answer in a fence despite instructions.
    function _unfence(s) {
        const segs = Markdown.segments(s);
        if (segs.length === 1 && segs[0].type === "code")
            return segs[0].content;
        return String(s).trim();
    }

    property Process output: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.error = I18n.t("ai.selection_copy_failed");
        }
    }
}
