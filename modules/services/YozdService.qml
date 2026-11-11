pragma Singleton

import QtQuick
import Quickshell
import "YozdClients.js" as YozdClients

Singleton {
    id: root

    property var focusedMonitor: null
    property var focusedWorkspace: null
    property var focusedClient: null

    // Compositor-level overview state (niri's native overview). Sourced
    // from `overview_open` in the compositor state dump; stays false on
    // compositors that don't emit overview events.
    property bool overviewOpen: false

    // Compositor backend name ("hyprland"/"niri"/"mango"), from
    // `yozd system get-compositor`. Empty until the daemon + yozd
    // daemon are up; probed with retries below.
    property string compositorName: ""

    property int focusHistoryCounter: 0

    // Serialized last workspace/monitor snapshots. compositor.state is
    // pushed on every window change (a terminal title spinner sends several
    // per second); re-publishing identical arrays would hand every
    // monitorFor()/focusedMonitor binding (bar, notch, dock, wallpaper,
    // corners, per screen) fresh objects and re-run them for nothing.
    property string _workspacesKey: ""
    property string _monitorsKey: ""

    property QtObject clients: QtObject {
        property var values: []
    }

    property QtObject monitors: QtObject {
        property var values: []
    }

    property QtObject workspaces: QtObject {
        property var values: []
    }
    // Ids of workspaces whose tag is urgent (MangoWC reports urgency per tag)
    property var urgentWorkspaceIds: []

    signal rawEvent(var event)

    function dispatch(command) {
        if (!command) return;

        const spaceIdx = command.indexOf(' ');
        const action = spaceIdx !== -1 ? command.substring(0, spaceIdx).trim() : command.trim();
        const rawArgs = spaceIdx !== -1 ? command.substring(spaceIdx + 1).trim() : "";

        const getAddr = (str) => {
            const m = str.match(/address:([^\s,]+)/);
            return m ? m[1] : str.trim();
        };

        let cmdArgs = [];

        if (action === "workspace") {
            cmdArgs = ["workspace", "switch", rawArgs];
        } else if (action === "closewindow") {
            cmdArgs = ["window", "close", getAddr(rawArgs)];
        } else if (action === "focuswindow") {
            cmdArgs = ["window", "focus", getAddr(rawArgs)];
        } else if (action === "movetoworkspacesilent") {
            const subParts = rawArgs.split(',');
            cmdArgs = ["window", "move-to-workspace-silent", subParts[0].trim()];
            if (subParts.length > 1) {
                cmdArgs.push(getAddr(subParts[1]));
            }
        } else if (action === "focusmonitor") {
            cmdArgs = ["monitor", "focus", rawArgs];
        } else if (action === "togglespecialworkspace") {
            cmdArgs = ["workspace", "toggle-special"];
            if (rawArgs) cmdArgs.push(rawArgs);
        } else if (action === "overview") {
            cmdArgs = ["overview", "toggle"];
        } else {
            cmdArgs = ["system", "execute", command];
        }

        BackendService.notify("compositor.dispatch", {args: cmdArgs.filter(x => x !== "" && x !== undefined)});
    }

    // Special workspaces (modules/specials): argv straight to yozd, no
    // command-string parsing (names and commands are data).
    function toggleSpecial(name) {
        BackendService.notify("compositor.dispatch", {
            args: ["workspace", "toggle-special", String(name || "")].filter(x => x !== "")
        });
    }

    // A workspace picked with a single click in the overview (the overview
    // stays open): the pointer stays where it is. Hyprland otherwise warps
    // it to the middle of the target monitor when the workspace lives on
    // another output. Switches that go there (double click, Enter) keep the
    // warp: with follow_mouse the keyboard focus follows the pointer.
    function switchWorkspaceKeepCursor(workspace) {
        if (workspace === undefined || workspace === null || workspace === "") return;
        BackendService.notify("compositor.dispatch", {
            args: ["workspace", "switch", String(workspace), "keep-cursor"]
        });
    }

    function moveToWorkspaceSilent(address, workspace) {
        if (!address || !workspace) return;
        BackendService.notify("compositor.dispatch", {
            args: ["window", "move-to-workspace-silent", String(workspace), String(address)]
        });
    }

    // Launches `command` so its window opens on `workspace`
    // ("special:Telegram silent").
    function execIn(command, workspace) {
        if (!command) return;
        BackendService.notify("compositor.dispatch", {
            args: ["system", "execute-in", String(workspace || ""), String(command)]
        });
    }

    function monitorFor(screen) {
        if (!screen) return null;
        const screenName = screen.name || screen;
        const values = root.monitors.values || [];
        for (let i = 0; i < values.length; i++) {
            if (values[i].name === screenName) return values[i];
        }
        return null;
    }

    function applyState(state) {
        if (!state) return;

        if (state.overview_open !== undefined && state.overview_open !== null) {
            root.overviewOpen = state.overview_open;
        }

        if (state.windows) {
            // Unchanged clients keep their object (YozdClients.js), so an
            // event that touches one window does not re-run bindings on the
            // others, and an event that touches none publishes nothing.
            const merged = YozdClients.merge(root.clients.values, state.windows, root.focusHistoryCounter);
            root.focusHistoryCounter = merged.counter;
            if (merged.changed) {
                root.clients.values = merged.values;
            }
            const focused = YozdClients.pickFocused(merged.values, root.focusedClient);
            if (focused !== root.focusedClient) {
                root.focusedClient = focused;
            }
        }

        if (state.workspaces) {
            const mappedWorkspaces = state.workspaces.map(ws => ({
                id: parseInt(ws.id) || 0,
                name: ws.name,
                monitor: ws.monitor_id,
                active: ws.is_active,
                urgent: !!(ws.metadata && ws.metadata.urgent),
                windows: 0
            }));
            const key = JSON.stringify(mappedWorkspaces);
            if (key !== root._workspacesKey) {
                root._workspacesKey = key;
                root.workspaces.values = mappedWorkspaces;
                root.urgentWorkspaceIds = mappedWorkspaces.filter(ws => ws.urgent).map(ws => ws.id);
                const focused = mappedWorkspaces.find(ws => ws.active) || null;
                if (focused !== root.focusedWorkspace) {
                    root.focusedWorkspace = focused;
                }
            }
        }

        if (state.monitors) {
            const mappedMonitors = state.monitors.map(mon => ({
                id: parseInt(mon.id) || 0,
                name: mon.name,
                focused: mon.is_focused,
                width: mon.width,
                height: mon.height,
                refreshRate: mon.refresh_rate,
                scale: mon.scale,
                x: mon.metadata ? (mon.metadata.x || 0) : 0,
                y: mon.metadata ? (mon.metadata.y || 0) : 0,
                transform: mon.metadata ? (mon.metadata.transform || 0) : 0,
                activeWorkspace: { id: parseInt(mon.metadata ? mon.metadata.active_workspace : 0) || 0, name: mon.metadata ? mon.metadata.active_workspace : "" }
            }));
            const key = JSON.stringify(mappedMonitors);
            if (key !== root._monitorsKey) {
                root._monitorsKey = key;
                root.monitors.values = mappedMonitors;
                const focused = mappedMonitors.find(mon => mon.focused) || null;
                if (focused !== root.focusedMonitor) {
                    root.focusedMonitor = focused;
                }
            }
        }
    }

    // Subscribe to the compositor service owned by the Go daemon. State
    // events arrive as raw {windows, workspaces, monitors} payloads; the
    // subscription auto-reconnects via BackendService when the daemon
    // restarts (e.g. after `yozakura reload`). An explicit state call also
    // runs first so the initial snapshot is captured even if the daemon
    // emitted events before the subscription was wired up.
    property var compositorSub: null

    Timer {
        id: compositorNameProbe
        interval: 1000
        repeat: true
        property int attempts: 0

        onTriggered: {
            attempts++;
            if (attempts > 30) {
                running = false;
                return;
            }
            root.probeCompositorName();
        }
    }

    onCompositorNameChanged: {
        if (compositorName !== "") {
            compositorNameProbe.running = false;
        }
    }

    function probeCompositorName() {
        BackendService.call("compositor.dispatch", {args: ["system", "get-compositor"]}, (result, error) => {
            if (error || !result || result.error || result.exit_code !== 0) return;
            const name = (result.stdout || "").trim().toLowerCase();
            if (!name) return;
            Qt.callLater(() => {
                root.compositorName = name;
                compositorNameProbe.running = false;
            });
        });
    }

    Component.onCompleted: {
        if (typeof BackendService.call === "function") {
            BackendService.call("compositor.state", {}, (result, error) => {
                if (result && !error) applyState(result);
            });
        }
        // Fire the first probe immediately; the timer only handles retries.
        probeCompositorName();
        compositorNameProbe.running = true;
        compositorSub = BackendService.addSubscription(["compositor"], (service, data) => {
            if (service !== "compositor.state" || !data) return;
            applyState(data);
            const ev = {
                service: "compositor",
                method: "state",
                data: data
            };
            root.rawEvent(ev);
        });
    }

    Component.onDestruction: {
        if (compositorSub !== null) {
            BackendService.removeSubscription(compositorSub);
        }
    }
}
