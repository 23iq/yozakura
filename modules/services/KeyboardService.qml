pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.config
import "KeyboardModel.js" as KeyboardModel

// Keyboard layouts: the XKB catalog, the active layout (live, from the
// backend `keyboard` service) and instant application of the keyboard config
// domain. The same settings are rendered into the compositor config by
// CompositorTomlWriter (input()), so they also survive a compositor restart.
Singleton {
    id: root

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
    readonly property string shortLabel: root.active.short || (Config.keyboardReady && Config.keyboard.layouts.length > 0 ? KeyboardModel.shortName(Config.keyboard.layouts[0].layout) : "")
    readonly property bool indicatorVisible: Config.keyboardReady && Config.keyboard.showIndicator && Config.keyboard.layouts.length > 1

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
        if (!Config.keyboardReady)
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
    }

    Component.onCompleted: {
        BackendService.addSubscription(["keyboard"], (service, data) => {
            if (service === "keyboard.layout")
                Qt.callLater(() => root._onLayout(data));
        });
    }
}
