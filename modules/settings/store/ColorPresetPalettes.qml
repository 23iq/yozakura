pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals

// Palettes of the static color presets (assets/colors/<name>/{dark,light}.json,
// user presets in <configDir>/colors) for the preset thumbnails: a look that
// names a color preset is drawn with it, not with the wallpaper's scheme.
// Lazy: ensure(name) loads one preset, one process at a time.
Singleton {
    id: root

    readonly property string officialDir: decodeURIComponent(Qt.resolvedUrl("../../../assets/colors").toString().replace("file://", ""))
    readonly property string userDir: Brand.configDir + "/colors"

    // {name: {dark: {role: hex}, light: {role: hex}}}
    property var palettes: ({})
    // Names that could not be read (the scheme palette is used instead).
    property var failed: ({})
    property var queue: []

    // True while a named preset's palette is still to come.
    function pending(name) {
        return !!name && !palettes[name] && !failed[name];
    }

    function ensure(name) {
        if (!pending(name) || queue.indexOf(name) >= 0 || proc.name === name)
            return;
        queue = queue.concat([name]);
        next();
    }

    function next() {
        if (proc.running || queue.length === 0)
            return;
        proc.name = queue[0];
        queue = queue.slice(1);
        // Official first, then user; the names are positional args.
        proc.command = ["sh", "-c", 'f() { if [ -f "$1/$3/$4.json" ]; then cat -- "$1/$3/$4.json"; else cat -- "$2/$3/$4.json"; fi; }; printf "{\\"dark\\":"; f "$1" "$2" "$3" dark; printf ",\\"light\\":"; f "$1" "$2" "$3" light; printf "}"', "color-preset", officialDir, userDir, proc.name];
        proc.running = true;
    }

    function settle(name, doc) {
        if (doc) {
            const p = Object.assign({}, palettes);
            p[name] = doc;
            palettes = p;
        } else {
            const f = Object.assign({}, failed);
            f[name] = true;
            failed = f;
        }
        next();
    }

    Process {
        id: proc

        property string name: ""

        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            let doc = null;
            if (code === 0) {
                try {
                    doc = JSON.parse(out.text);
                } catch (e) {}
            }
            root.settle(proc.name, doc);
        }
    }
}
