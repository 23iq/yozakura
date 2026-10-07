pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Palettes every matugen scheme would produce for the current wallpaper,
// computed by the backend (`yozakura schemes <image>`, cached on disk), for
// the scheme gallery and the theme mode cards. Lazy: nothing runs until a
// view calls refresh().
Singleton {
    id: root

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: manager ? (manager.currentWallpaper || "") : ""
    readonly property string source: manager && wallpaper ? manager.getColorSource(wallpaper) : ""

    // {scheme: {dark: {role: hex}, light: {role: hex}}}
    property var palettes: ({})
    property string loadedSource: ""
    readonly property bool loading: proc.running && loadedSource !== source
    property bool failed: false
    property bool wanted: false

    function refresh() {
        wanted = true;
        if (!source || source === loadedSource || proc.running)
            return;
        failed = false;
        proc.requested = source;
        proc.command = [Brand.appBin, "schemes", source];
        proc.running = true;
    }

    // Palette of `scheme` for "dark"/"light", or null while unknown.
    function palette(scheme, mode) {
        const s = palettes[scheme];
        return s && s[mode] ? s[mode] : null;
    }

    onSourceChanged: if (wanted)
        refresh()

    Process {
        id: proc
        property string requested: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const doc = JSON.parse(text);
                    root.palettes = doc.schemes || {};
                    root.loadedSource = proc.requested;
                } catch (e) {
                    root.failed = true;
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.failed = true;
            // The wallpaper changed while matugen ran.
            if (root.source !== proc.requested)
                Qt.callLater(root.refresh);
        }
    }
}
