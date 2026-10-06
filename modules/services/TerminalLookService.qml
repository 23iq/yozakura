pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import "../terminal/TermModel.js" as TermModel

// Terminal look: the prompt presets, rendered previews and fish/engine
// status of the backend `term` service (backend/pkg/svc/term), shown by the
// prompt gallery (modules/terminal). Previews are cached per engine +
// preset and re-fetched when the palette or the installed engines change.
// Installs go through ExtrasService (starship, oh-my-posh, fish, login
// shell); the backend writes the prompt files, never QML.
Singleton {
    id: root

    // [{id, name, description (i18n key), nerdFont, lines}]
    property var presets: []
    // {enabled, engine, fishInstalled, fishIsLoginShell, engineInstalled:
    // {starship, ohmyposh}, foreignPromptInit, foreignFile, hookPresent}
    property var status: null
    // previewKey(engine, id) -> {left: [[span]], right: [span], exact, engine, reason}
    property var previews: ({})
    property string error: ""

    readonly property string engine: Config.terminal ? Config.terminal.engine : "starship"
    readonly property string prompt: Config.terminal ? Config.terminal.prompt : ""
    readonly property bool fishInstalled: !!(root.status && root.status.fishInstalled)
    // The kitty font when installed, else the shell mono font or a Nerd
    // Font that is (the preview must show the glyphs), at the kitty size.
    readonly property string fontFamily: TermModel.pickFont([Config.apps && Config.apps.kitty ? Config.apps.kitty.font : "", Config.theme.monoFont, "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"], root._families)
    readonly property real fontPixelSize: Math.round(((Config.apps && Config.apps.kitty ? Number(Config.apps.kitty.fontSize) : 11) || 11) * 4 / 3)
    readonly property var _families: Qt.fontFamilies()

    property bool _loaded: false
    // keys asked for (re-fetched after an invalidation), keys in flight
    property var _wanted: ({})
    property var _pending: ({})
    property int _generation: 0
    // "Make fish my default shell" waits for the fish install to finish.
    property bool _chshAfterInstall: false
    property string _paletteSig: ""
    property string _enginesSig: ""

    readonly property string fishPath: "/usr/bin/fish"

    function load() {
        if (!root._loaded) {
            root._loaded = true;
            BackendService.call("term.presets", {}, (result, error) => {
                if (error || !result) {
                    root._loaded = false;
                    root.error = String(error || "");
                    return;
                }
                root.presets = result;
            });
            ExtrasService.load();
        }
        root.refreshStatus();
    }

    function refreshStatus() {
        BackendService.call("term.status", {}, (result, error) => {
            if (!error && result)
                root._setStatus(result);
        });
    }

    function _setStatus(st) {
        root.status = st;
        const inst = st.engineInstalled || {};
        const sig = (inst.starship ? "s" : "-") + (inst.ohmyposh ? "o" : "-");
        if (root._enginesSig !== "" && sig !== root._enginesSig)
            root.invalidate();
        root._enginesSig = sig;
        if (root._chshAfterInstall && st.fishInstalled) {
            root._chshAfterInstall = false;
            ExtrasService.setLoginShell(root.fishPath);
        }
    }

    // Cached preview of preset `id` drawn by `engine` (undefined until it
    // arrives: read it from `previews` in bindings, call ensure() once).
    function previewOf(id, engine) {
        return root.previews[TermModel.previewKey(engine, id)];
    }

    function ensure(id, engine) {
        if (!id || !engine)
            return;
        const key = TermModel.previewKey(engine, id);
        if (!root._wanted[key]) {
            const w = Object.assign({}, root._wanted);
            w[key] = {
                "id": id,
                "engine": engine
            };
            root._wanted = w;
        }
        if (root.previews[key] === undefined)
            root._queue(key);
    }

    // Requests leave on the next tick (never from inside a binding update).
    property var _queued: []
    function _queue(key) {
        if (root._queued.indexOf(key) < 0)
            root._queued.push(key);
        Qt.callLater(root._drain);
    }
    function _drain() {
        const keys = root._queued;
        root._queued = [];
        keys.forEach(key => root._fetch(key));
    }

    function _fetch(key) {
        const want = root._wanted[key];
        if (!want || root._pending[key])
            return;
        root._pending[key] = true;
        const gen = root._generation;
        BackendService.call("term.preview", {
            "prompt": want.id,
            "engine": want.engine
        }, (result, error) => {
            if (gen !== root._generation)
                return;
            delete root._pending[key];
            if (error || !result)
                return;
            const next = Object.assign({}, root.previews);
            next[key] = result;
            root.previews = next;
        });
    }

    // Fetch every wanted preview again; the old pictures stay until the new
    // ones arrive, answers to older requests are dropped.
    function invalidate() {
        root._generation++;
        root._pending = ({});
        Object.keys(root._wanted).forEach(key => root._queue(key));
    }

    // Pick a prompt: switches it on (an existing prompt is only replaced
    // once the user picks one) and queues the engine when it is missing.
    function choose(id) {
        if (!Config.terminal)
            return;
        Config.terminal.prompt = id;
        Config.terminal.enabled = true;
        Config.saveTerminal();
        const st = root.status;
        if (st && st.engineInstalled && !st.engineInstalled[root.engine])
            root.installEngine(root.engine);
    }

    function installEngine(engine) {
        ExtrasService.install([TermModel.engineExtra(engine)]);
    }

    // Install fish when needed, then make it the login shell (chsh through
    // the backend, asks for the password).
    function makeFishDefault() {
        if (root.fishInstalled) {
            ExtrasService.setLoginShell(root.fishPath);
            return;
        }
        root._chshAfterInstall = true;
        ExtrasService.install(["fish"]);
    }

    function apply() {
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 400
        onTriggered: BackendService.call("term.apply", {}, (result, error) => {
            if (!error && result)
                root._setStatus(result);
        })
    }

    // Palette crossfades change the roles many times: settle first.
    Timer {
        id: paletteTimer
        interval: 600
        onTriggered: {
            const sig = String(Colors.primary) + String(Colors.secondary) + String(Colors.tertiary) + String(Colors.background) + String(Colors.surfaceContainerHigh);
            if (sig !== root._paletteSig) {
                root._paletteSig = sig;
                root.invalidate();
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 800
        onTriggered: root.refreshStatus()
    }

    Connections {
        target: Colors
        function onPrimaryChanged() {
            paletteTimer.restart();
        }
        function onBackgroundChanged() {
            paletteTimer.restart();
        }
    }

    // Installs and the login shell change what `term.status` reports.
    Connections {
        target: ExtrasService
        function onStatusChanged() {
            if (root._loaded)
                statusTimer.restart();
        }
        function onJobsChanged() {
            if (root._loaded)
                statusTimer.restart();
        }
    }

    Connections {
        target: Config.terminal
        function onPromptChanged() {
            root.apply();
        }
        function onEnabledChanged() {
            root.apply();
        }
        function onEngineChanged() {
            root.apply();
        }
        function onGreetingChanged() {
            root.apply();
        }
    }

    Component.onCompleted: root._paletteSig = String(Colors.primary) + String(Colors.secondary) + String(Colors.tertiary) + String(Colors.background) + String(Colors.surfaceContainerHigh)
}
