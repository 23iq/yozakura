import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import qs.modules.services.activities
import "Automations.js" as Logic
import "../../aicenter/lib/Markdown.js" as Markdown

// Runs AI automations (Config.ai.automations): schedules (cron), login
// briefing, finished transfers, clipboard regex (e.g. stack traces) and new
// screenshots. Only instantiated while at least one automation is enabled.
QtObject {
    id: root

    readonly property var list: Config.ai.automations || []
    property var _lastRuns: ({})
    property var _transfers: []
    property string _lastClip: ""
    property bool _primed: false
    property int _clipSub: -1

    // a: normalized automation; vars: template variables; attachments: images
    function trigger(a, vars, attachments) {
        if (a.offer) {
            offer(a, vars, attachments);
            return;
        }
        execute(a, vars, attachments);
    }

    function execute(a, vars, attachments) {
        Ai.expandTemplate(a.prompt, vars, prompt => {
            if (a.output === "sidebar") {
                Ai.setMode("chat");
                if (!GlobalStates.assistantVisible)
                    GlobalStates.toggleAssistant();
                Ai.send(prompt, attachments || []);
                return;
            }
            if (a.output === "quickask") {
                Ai.askQuick(prompt, attachments || []);
                return;
            }
            Ai.runPrompt(prompt, {
                model: a.model,
                attachments: attachments || []
            }, (text, error) => {
                if (error) {
                    notify(a.name, error);
                    return;
                }
                if (a.output === "clipboard") {
                    run(["wl-copy", "--", text]);
                    notify(a.name, I18n.t("ai.copied_result"));
                } else {
                    notify(a.name, Markdown.plain(text));
                }
            });
        });
    }

    // Shows a notification with an action; runs the automation when clicked.
    function offer(a, vars, attachments) {
        const p = offerFactory.createObject(root, {
            command: ["notify-send", "-a", "Yozakura AI", "-i", "dialog-information", "-A", "run=" + (a.name || I18n.t("ai.run")), "-w", a.name || "AI", I18n.t("ai.offer_body")]
        });
        p.onAction = () => execute(a, vars, attachments);
        p.running = true;
    }

    function notify(title, body) {
        run(["notify-send", "-a", "Yozakura AI", title || "AI", String(body || "").substring(0, 1200)]);
    }

    readonly property Component procFactory: Component {
        Process {
            onExited: destroy()
        }
    }
    readonly property Component offerFactory: Component {
        Process {
            id: offerProc
            property var onAction: null
            stdout: StdioCollector {
                onStreamFinished: if (text.trim() === "run" && offerProc.onAction)
                    offerProc.onAction()
            }
            onExited: destroy()
        }
    }

    function run(cmd) {
        procFactory.createObject(root, {
            command: cmd,
            running: true
        });
    }

    // ── schedule ──
    property Timer clock: Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const r = Logic.dueSchedules(root.list, new Date(), root._lastRuns);
            for (const a of r.due) {
                root._lastRuns[a.id] = r.key;
                root.trigger(a, {}, []);
            }
        }
    }

    // ── login (once per day, shortly after the shell starts) ──
    property Timer login: Timer {
        interval: 15000
        running: StateService.initialized
        onTriggered: {
            const items = Logic.active(root.list, "login");
            if (items.length === 0)
                return;
            const r = Logic.loginDue(StateService.get("aiLoginRun", ""), new Date());
            if (!r.due)
                return;
            StateService.set("aiLoginRun", r.today);
            for (const a of items)
                root.trigger(a, {}, []);
        }
    }

    // ── transfers ──
    property Connections transfersWatch: Connections {
        target: ActivityService
        function onTransfersChanged() {
            const now = (ActivityService.transfers || []).map(t => ({
                        id: t.id,
                        state: t.state,
                        kind: t.kind,
                        title: t.title || t.app || ""
                    }));
            const done = Logic.completedTransfers(root._transfers, now);
            root._transfers = now;
            const items = Logic.active(root.list, "transfer");
            for (const t of done)
                for (const a of items)
                    if (Logic.transferMatches(a, t))
                        root.trigger(a, {
                            input: t.title + " (" + t.kind + ")"
                        }, []);
        }
    }

    // ── clipboard ──
    property Process clipRead: Process {
        command: ["wl-paste", "-n", "-t", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root._lastClip)
                    return;
                const primed = root._primed;
                root._lastClip = text;
                root._primed = true;
                if (!primed)
                    return; // what was already on the clipboard is not "copied now"
                for (const a of Logic.clipboardMatches(root.list, text))
                    root.trigger(a, {
                        clipboard: text
                    }, []);
            }
        }
    }

    // ── screenshots ──
    property Connections shotWatch: Connections {
        target: Screenshot
        function onImageSaved(path) {
            const items = Logic.active(root.list, "screenshot");
            if (items.length === 0)
                return;
            Ai._ensureInit();
            Ai.context.imageFile(path, att => {
                for (const a of items)
                    root.trigger(a, {
                        file: path
                    }, att ? [att] : []);
            });
        }
    }

    readonly property bool _wantsClipboard: Logic.active(list, "clipboard").length > 0
    on_WantsClipboardChanged: _syncClipboard()
    Component.onCompleted: _syncClipboard()
    Component.onDestruction: {
        if (_clipSub >= 0)
            BackendService.removeSubscription(_clipSub);
    }

    function _syncClipboard() {
        if (_wantsClipboard && _clipSub < 0) {
            clipRead.running = true;
            _clipSub = BackendService.addSubscription(["clipboard"], (service, data) => {
                if (service === "clipboard.refresh" && !clipRead.running)
                    clipRead.running = true;
            });
        } else if (!_wantsClipboard && _clipSub >= 0) {
            BackendService.removeSubscription(_clipSub);
            _clipSub = -1;
        }
    }
}
