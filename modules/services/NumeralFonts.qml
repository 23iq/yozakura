pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../bar/workspaces/WorkspaceNumerals.js" as Numerals

// Font for workspace numerals. workspaces.numeralFont wins when set;
// otherwise the selected numeral system's auto font: a bundled (subset)
// font when its file exists and has every glyph of the label, else the
// best preferred system family for the system's language (never one of its
// `avoid` families, e.g. serif/mincho for kanji), else the theme font. The
// probe (bundled files + fc-list) runs once per numeral system, when used.
Singleton {
    id: root

    readonly property var numeralSystem: Numerals.get(Config.workspaces.numeralStyle)
    readonly property var fontSpec: numeralSystem.font
    // numeral system id -> { bundledFile, systemFamily }
    property var probes: ({})
    readonly property var probe: probes[numeralSystem.id] || null
    readonly property var bundledEntry: {
        if (!fontSpec || !probe || !probe.bundledFile)
            return null;
        return fontSpec.bundled.find(entry => probe.bundledFile.endsWith("/" + entry.file)) || null;
    }

    function usesBundled(text) {
        return !Config.workspaces.numeralFont && !!bundledEntry && bundledFont.status === FontLoader.Ready && Numerals.covers(bundledEntry.coverage, text);
    }

    function family(text) {
        const override = Config.workspaces.numeralFont;
        if (override)
            return override;
        if (!fontSpec)
            return Config.theme.font;
        if (usesBundled(text))
            return bundledFont.name;
        if (probe && probe.systemFamily)
            return probe.systemFamily;
        return Config.theme.font;
    }

    function weight(text) {
        if (usesBundled(text) && bundledEntry.weight)
            return bundledEntry.weight;
        return fontSpec && fontSpec.weight ? fontSpec.weight : Font.Normal;
    }

    function runProbe() {
        // Read the system directly: change handlers may run before the
        // derived bindings above are refreshed.
        const system = numeralSystem;
        const spec = system.font;
        if (!spec || probes[system.id] || probeProcess.running)
            return;
        const files = spec.bundled.map(entry => Quickshell.shellDir + "/" + entry.file);
        probeProcess.systemId = system.id;
        probeProcess.prefer = spec.prefer;
        probeProcess.avoid = spec.avoid || [];
        probeProcess.command = ["sh", "-c", 'for f in "$@"; do [ -f "$f" ] && printf "file:%s\\n" "$f"; done; fc-list ":lang=$0" family 2>/dev/null', spec.lang].concat(files);
        probeProcess.running = true;
    }

    onNumeralSystemChanged: runProbe()
    Component.onCompleted: runProbe()

    FontLoader {
        id: bundledFont
        source: root.bundledEntry ? "file://" + root.probe.bundledFile : ""
    }

    Process {
        id: probeProcess
        property string systemId: ""
        property var prefer: []
        property var avoid: []
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.probes);
                next[probeProcess.systemId] = Numerals.parseFontProbe(text, probeProcess.prefer, probeProcess.avoid);
                root.probes = next;
            }
        }
        // The style may have changed while this probe ran.
        onExited: {
            if (probeProcess.systemId !== root.numeralSystem.id)
                Qt.callLater(root.runProbe);
        }
    }
}
