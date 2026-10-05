import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.theme
import qs.modules.services
import "BorderPulse.js" as Pulse

// Music-reactive active window border (compositor.borderPulse): while music
// plays, the focused window's border (and its shadow glow) breathes with
// the bass of the shared cava spectrum.
//
// Cost model: nothing runs unless the pulse is enabled, a player is
// playing and the compositor is Hyprland. Then a 30 Hz tick reads
// CavaService.values (cava is shared with the notch visualizer), and only
// a change of the quantized level (Pulse.STEPS) sends one `eval` straight
// to Hyprland's request socket - no process spawn per frame. When the
// music stops the exact base border is restored.
QtObject {
    id: root

    readonly property var cfg: Config.compositor ? Config.compositor.borderPulse : null
    readonly property string socketPath: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        const run = Quickshell.env("XDG_RUNTIME_DIR");
        return sig && run ? run + "/hypr/" + sig + "/.socket.sock" : "";
    }
    readonly property bool wanted: !!cfg && cfg.enabled && cfg.source === "cava" && socketPath !== "" && CavaService.available
    readonly property bool active: wanted && MprisController.isPlaying && !GameModeClient.toggled

    readonly property string consumerKey: "border-pulse"
    property real level: 0
    property int step: -1
    property var base: null
    property string _pending: ""

    onActiveChanged: {
        CavaService.setConsumer(root.consumerKey, root.active);
        if (root.active) {
            root.base = root.capture();
            root.level = 0;
            root.step = -1;
        } else if (root.base) {
            // Back to the exact configured border (fresh, in case it changed).
            root.base = null;
            root.send(Pulse.frameLua(root.capture(), 1, 0));
        }
    }

    property Timer ticker: Timer {
        interval: 33
        repeat: true
        running: root.active
        onTriggered: root.tick()
    }

    function tick() {
        if (!root.base)
            return;
        root.level = Pulse.follow(root.level, Pulse.energy(CavaService.values), 0.55, 0.12);
        const s = Pulse.quantize(root.level, Pulse.STEPS);
        if (s === root.step)
            return;
        root.step = s;
        root.send(Pulse.frameLua(root.base, s / Pulse.STEPS, root.cfg ? root.cfg.intensity : 0.6));
    }

    // Active border + shadow color exactly as the compositor config builds them.
    function capture() {
        const hl = CompositorTomlWriter.buildHyprlandConfig();
        return {
            "border": hl.general.col.active_border,
            "shadow": hl.decoration.shadow.enabled ? hl.decoration.shadow.color : ""
        };
    }

    // The base follows edits and palette changes made while pulsing.
    function recapture() {
        if (root.active)
            root.base = root.capture();
    }

    property Connections compositorConnections: Connections {
        target: Config.compositor
        function onActiveBorderColorChanged() {
            root.recapture();
        }
        function onBorderAngleChanged() {
            root.recapture();
        }
        function onShadowColorChanged() {
            root.recapture();
        }
        function onShadowEnabledChanged() {
            root.recapture();
        }
    }

    property Connections colorConnections: Connections {
        target: Colors
        function onFileChanged() {
            root.recapture();
        }
    }

    // One request per connection (Hyprland answers and closes); only the
    // newest frame is kept while a request is in flight.
    function send(lua) {
        root._pending = "eval " + lua;
        if (!hyprSocket.connected)
            hyprSocket.connected = true;
    }

    property Socket hyprSocket: Socket {
        id: hyprSocket
        path: root.socketPath
        connected: false
        parser: SplitParser {}
        onConnectionStateChanged: {
            if (hyprSocket.connected) {
                if (root._pending) {
                    hyprSocket.write(root._pending);
                    hyprSocket.flush();
                    root._pending = "";
                }
            } else if (root._pending) {
                hyprSocket.connected = true;
            }
        }
        onError: error => {
            console.warn("BorderPulse: compositor socket error", error);
            root._pending = "";
        }
    }

    Component.onDestruction: CavaService.setConsumer(root.consumerKey, false)
}
