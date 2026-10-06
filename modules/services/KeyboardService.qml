pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.config
import "KeyboardModel.js" as KeyboardModel

// Keyboard layouts: the XKB catalog, the active layout (live, from the
// backend `keyboard` service) and instant application of the keyboard config
// domain. The same settings are rendered into the compositor config by
// CompositorTomlWriter (compositorInput()), so they also survive a
// compositor restart.
//
// Ruling K-1: nothing is rendered or applied until keyboard.managed. Before,
// the user's own compositor settings stay in effect and the UI shows them
// (`current`, read through the backend); the first edit() copies them into
// the domain, sets managed and only then applies.
Singleton {
    id: root

    // Yozakura renders and applies the keyboard domain
    readonly property bool managed: Config.keyboardReady && Config.keyboard.managed === true
    // The compositor's settings in the domain's shape ({available, layouts,
    // switchBind, options, repeatRate, repeatDelay}); null until read
    property var current: null
    // The UI may edit: managed, or the compositor's values are known
    readonly property bool known: root.managed || root.current !== null
    // The compositor cannot report its settings (nothing in its config):
    // taking over replaces them, so it needs an explicit takeOver()
    readonly property bool unreadable: !root.managed && root.current !== null && !root.current.available
    // Edits waiting for keyboard.current (a takeover re-reads it first)
    property var _queue: []
    property bool _reading: false
    property int _retries: 0
    // What the UI shows: the domain once managed, the compositor's values before
    readonly property var effective: KeyboardModel.effective(root.managed, Config.keyboardReady ? Config.keyboard : null, root.current)

    // Parsed rules list {layouts:[{name, description, variants}], options, groups}, loaded on first use
    property var catalog: null
    property bool catalogRequested: false

    // Active layout {name, index, code, short}
    property var active: ({
            "name": "",
            "index": 0,
            "code": "",
            "short": ""
        })

    // Before the first keyboard.layout event: the first configured layout
    readonly property string shortLabel: root.active.short || (root.effective.layouts.length > 0 ? KeyboardModel.shortName(root.effective.layouts[0].layout) : "")
    readonly property bool indicatorVisible: Config.keyboardReady && Config.keyboard.showIndicator && root.effective.layouts.length > 1

    function shortName(layout) {
        return KeyboardModel.shortName(layout);
    }

    // The keyboard domain as the backend expects it (compositor payload and keyboard.apply)
    function input() {
        const k = Config.keyboard;
        return {
            "layouts": Array.from(k.layouts).map(l => ({
                        "layout": l.layout || "",
                        "variant": l.variant || ""
                    })),
            "switchBind": k.switchBind,
            "options": Array.from(k.options),
            "repeatRate": k.repeatRate,
            "repeatDelay": k.repeatDelay
        };
    }

    // The keyboard domain for the compositor config: null (nothing rendered,
    // the user's own settings stay) until managed.
    function compositorInput() {
        return root.managed ? root.input() : null;
    }

    // Reads the compositor's settings (read only), retrying on errors (a new
    // call starts a fresh round of retries); then runs the queued edits.
    function refreshCurrent() {
        root._retries = 0;
        root._read();
    }

    function _read() {
        if (root._reading)
            return;
        root._reading = true;
        BackendService.call("keyboard.current", {}, (result, error) => {
            root._reading = false;
            if (error || !result) {
                console.warn("KeyboardService: current failed", JSON.stringify(error));
                if (root._retries++ < 10)
                    retryTimer.restart();
                return;
            }
            root._retries = 0;
            root.current = result;
            root._flush();
        });
    }

    // Every user change of the keyboard goes through here (settings page,
    // onboarding): `patch` holds the new values ({layouts: [...]},
    // {repeatRate: 40}, {showIndicator: false}). The first change of a
    // compositor key re-reads the compositor's settings right before taking
    // them over; edits made meanwhile are queued, never dropped.
    function edit(patch) {
        if (!Config.keyboardReady)
            return;
        if (root._reading || root._queue.length > 0 || (!root.managed && KeyboardModel.touchesCompositor(patch))) {
            root._queue = root._queue.concat([patch]);
            root.refreshCurrent();
            return;
        }
        root._write(patch);
    }

    // Explicit takeover where the compositor's settings cannot be read
    // (unreadable): the configured values replace them from now on.
    function takeOver() {
        if (Config.keyboardReady && !root.managed)
            root._write({
                "managed": true
            });
    }

    function _flush() {
        const queue = root._queue;
        root._queue = [];
        for (const patch of queue) {
            if (root.unreadable && KeyboardModel.touchesCompositor(patch)) {
                console.warn("KeyboardService: the compositor's settings cannot be read; takeOver() first");
                continue;
            }
            root._write(patch);
        }
    }

    function _write(patch) {
        const writes = KeyboardModel.planEdit(root.managed, root.current, patch, Config.keyboard);
        Config.pauseAutoSave = true;
        for (const key in writes)
            Config.keyboard[key] = writes[key];
        Config.pauseAutoSave = false;
        Config.saveKeyboard();
    }

    Timer {
        id: retryTimer
        interval: 1000
        onTriggered: root._read()
    }

    function loadCatalog() {
        if (root.catalogRequested)
            return;
        root.catalogRequested = true;
        BackendService.call("keyboard.catalog", {}, (result, error) => {
            if (error || !result) {
                root.catalogRequested = false;
                console.warn("KeyboardService: catalog failed", JSON.stringify(error));
                return;
            }
            root.catalog = result;
        });
    }

    function next() {
        BackendService.call("keyboard.next", {}, (result, error) => {
            if (error)
                console.warn("KeyboardService: next failed", JSON.stringify(error));
        });
    }

    function apply() {
        if (!root.managed)
            return;
        BackendService.call("keyboard.apply", root.input(), (result, error) => {
            if (error)
                console.warn("KeyboardService: apply failed", JSON.stringify(error));
        });
    }

    function _onLayout(data) {
        if (!data)
            return;
        root.active = {
            "name": data.name || "",
            "index": data.index || 0,
            "code": data.code || "",
            "short": data.short || root.shortName(data.code)
        };
    }

    Timer {
        id: applyDebounce
        interval: 400
        onTriggered: root.apply()
    }

    Connections {
        target: Config.keyboardReady ? Config.keyboard : null
        function onLayoutsChanged() {
            applyDebounce.restart();
        }
        function onSwitchBindChanged() {
            applyDebounce.restart();
        }
        function onOptionsChanged() {
            applyDebounce.restart();
        }
        function onRepeatRateChanged() {
            applyDebounce.restart();
        }
        function onRepeatDelayChanged() {
            applyDebounce.restart();
        }
        function onManagedChanged() {
            applyDebounce.restart();
        }
    }

    Component.onCompleted: {
        root.refreshCurrent();
        BackendService.addSubscription(["keyboard"], (service, data) => {
            if (service === "keyboard.layout")
                Qt.callLater(() => root._onLayout(data));
        });
    }
}
