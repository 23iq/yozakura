pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import "PanelLayout.js" as PanelLayout
// Lets Quickshell's scanner reach the style components (loaded by URL)
import "styles" as PanelStyleFiles

// The configured panels (bar.panels, or the legacy single bar), resolved
// once for the whole shell. Per screen: forScreen(); see PanelHost.qml.
Singleton {
    id: root

    readonly property var resolved: Config.barReady ? PanelLayout.normalize(Config.bar) : PanelLayout.normalize(undefined)
    readonly property var all: resolved.panels
    readonly property bool legacy: resolved.legacy
    readonly property string notchEdge: Config.notchPosition !== undefined ? Config.notchPosition : "top"

    // Edge of the panel the notch pairs with (or of the first panel): what
    // "the bar position" means for code that only knows one bar.
    readonly property string primaryEdge: {
        const list = all.filter(p => p.enabled);
        const i = PanelLayout.primaryIndex(list, notchEdge);
        return i === -1 ? "top" : list[i].edge;
    }

    onResolvedChanged: {
        for (let i = 0; i < resolved.warnings.length; i++)
            console.warn("Panels: " + resolved.warnings[i]);
    }

    function screenIndex(name) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return i;
        }
        return 0;
    }

    // Panels shown on a screen, in config order.
    function forScreen(name) {
        return PanelLayout.forScreen(all, name, screenIndex(name));
    }

    // One flip of the shared pin per keybind press (every panel follows it).
    function togglePinned() {
        if (Config.bar)
            Config.bar.pinnedOnStartup = !Config.bar.pinnedOnStartup;
    }

    Connections {
        target: GlobalStates
        function onBarPinToggled() {
            root.togglePinned();
        }
    }
}
