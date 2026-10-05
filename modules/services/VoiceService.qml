pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.services
import qs.config
import "voice/VoiceModel.js" as VoiceModel

// Voice input client: mirrors the backend `voice` service (state, levels),
// opens the listening panel in the notch and hands finished transcripts to
// the AI center or types them into the focused window (dictation).
// Recording, VAD and whisper all live in backend/pkg/svc/voice.
Singleton {
    id: root

    // Backend snapshot (see Snapshot in backend/pkg/svc/voice/session.go)
    property string state: "idle"
    property int session: 0
    property string target: "ai"
    property string activation: "push-to-talk"
    property bool handsFree: false
    property int elapsedMs: 0
    property string language: "auto"
    property string text: ""
    property string reason: ""
    property string error: ""
    property int transcribeMs: 0

    // Live audio (voice.level, ~31 fps while listening)
    property real level: 0
    property var bands: []
    property bool speech: false

    readonly property bool active: VoiceModel.isActive(state)
    // True while the listening panel should be shown (the notch's "voice"
    // panel, NotchPanels.js), on panelScreen ("" = every screen)
    property bool panelOpen: false
    property string panelScreen: ""
    readonly property int bandCount: 24

    property int subHandle: -1

    function start(target: string) {
        BackendService.call("voice.start", {
            target: target
        });
    }

    function press(target: string) {
        BackendService.call("voice.press", {
            target: target
        });
    }

    function stop() {
        BackendService.call("voice.stop", {});
    }

    function cancel() {
        BackendService.call("voice.cancel", {});
    }

    function applySnapshot(snap) {
        if (!snap)
            return;
        const prevState = root.state;
        const prevSession = root.session;
        root.session = snap.session ?? 0;
        root.target = snap.target || "ai";
        root.activation = snap.mode || "push-to-talk";
        root.handsFree = snap.handsFree === true;
        root.language = snap.language || "auto";
        root.reason = snap.reason || "";
        root.error = snap.error || "";
        root.text = snap.text || "";
        root.transcribeMs = snap.transcribeMs ?? 0;
        if (snap.elapsedMs !== undefined && snap.state !== "listening")
            root.elapsedMs = snap.elapsedMs;
        root.state = snap.state || "idle";

        const fresh = root.session !== prevSession || root.state !== prevState;
        if (!fresh)
            return;
        if (root.state === "listening" && prevState !== "listening") {
            root.elapsedMs = 0;
            root.bands = [];
            root.level = 0;
            root.openPanel();
        } else if (VoiceModel.isTerminal(root.state) && prevState !== "idle") {
            root.finish();
        }
    }

    function applyLevel(data) {
        if (!data || data.session !== root.session || root.state !== "listening")
            return;
        root.level = data.level ?? 0;
        root.bands = data.bands || [];
        root.speech = data.speech === true;
        root.elapsedMs = data.elapsedMs ?? root.elapsedMs;
    }

    function openPanel() {
        root.panelScreen = YozdService.focusedMonitor ? YozdService.focusedMonitor.name : "";
        root.panelOpen = true;
    }

    function closePanel() {
        root.panelOpen = false;
    }

    // The user closed the panel (Esc, click outside, another view took the
    // notch): an active session is cancelled; the mic must never outlive
    // its UI.
    function dismiss() {
        if (!root.panelOpen)
            return;
        root.panelOpen = false;
        if (root.active)
            root.cancel();
    }

    // Terminal state: keep the result on screen briefly, then deliver it.
    function finish() {
        if (root.state === "done" && root.text !== "") {
            deliverTimer.interval = Math.max(0, Config.voice.previewMs ?? 500);
            deliverTimer.pending = {
                text: root.text,
                target: root.target
            };
            deliverTimer.restart();
        } else if (root.state === "cancelled") {
            root.closePanel();
        } else {
            dismissTimer.interval = root.state === "error" ? 2600 : 1400;
            dismissTimer.restart();
        }
    }

    function deliver(text: string, target: string) {
        root.closePanel();
        if (target === "dictation") {
            // Let the compositor hand keyboard focus back to the window
            // before typing into it.
            typeTimer.pendingText = text;
            typeTimer.restart();
        } else {
            root.deliverToAi(text);
        }
    }

    // Voice to AI: sidebar input when the assistant sidebar is open,
    // otherwise the notch quick-ask.
    function deliverToAi(text: string) {
        const target = VoiceModel.aiTarget(GlobalStates.assistantVisible);
        VoiceModel.tryHandleVoice(Ai, text, target);
    }

    Timer {
        id: deliverTimer
        property var pending: null
        onTriggered: {
            if (pending)
                root.deliver(pending.text, pending.target);
            pending = null;
        }
    }

    Timer {
        id: dismissTimer
        onTriggered: {
            if (!root.active)
                root.closePanel();
        }
    }

    Timer {
        id: typeTimer
        property string pendingText: ""
        interval: 160
        onTriggered: {
            BackendService.call("voice.type", {
                text: pendingText
            });
            pendingText = "";
        }
    }

    IpcHandler {
        target: "voice"

        function press(target: string): void {
            root.press(target);
        }
        function stop(): void {
            root.stop();
        }
        function cancel(): void {
            root.cancel();
        }
        // Deliver text as if it had been dictated (debugging, AI center).
        function deliver(text: string, target: string): void {
            root.deliver(text, target);
        }
    }

    Component.onCompleted: {
        root.subHandle = BackendService.addSubscription(["voice"], (service, data) => {
            if (service === "voice.level")
                Qt.callLater(() => root.applyLevel(data));
            else if (service === "voice.state")
                Qt.callLater(() => root.applySnapshot(data));
        });
    }
}
