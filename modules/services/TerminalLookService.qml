pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import "../terminal/TermModel.js" as TermModel
import "../terminal/FetchModel.js" as FetchModel

// Terminal look: the prompt presets, rendered previews and fish/engine
// status of the backend `term` service (backend/pkg/svc/term), shown by the
// prompt gallery (modules/terminal), and the fastfetch greeting (its looks,
// previews of what fastfetch prints, status.greeting). Previews are cached
// per engine + preset (per look + logo) and re-fetched when the palette or
// the installed engines change.
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
    // Greeting looks [{id, name, description, logo, own}] and previews
    // (FetchModel.previewKey -> {lines: [[span]], exact, reason, imageLogo}).
    property var fetchPresets: []
    property var fetchPreviews: ({})
    // {on, fastfetchInstalled, ownConfig, shells: [{shell, state, file}], logoError, imageLogo}
    readonly property var greeting: root.status?.greeting ?? null
    readonly property bool fastfetchInstalled: !!(root.greeting && root.greeting.fastfetchInstalled) || ExtrasService.cardState("fastfetch") === "installed"
    property var _wantedFetch: ({})

    readonly property string engine: Config.terminal ? Config.terminal.engine : "starship"
    readonly property string prompt: Config.terminal ? Config.terminal.prompt : ""
    readonly property bool fishInstalled: !!(root.status && root.status.fishInstalled)
    // The kitty font when installed, else the shell mono font or a Nerd
    // Font that is (the preview must show the glyphs), at the kitty size.
    readonly property string fontFamily: TermModel.pickFont([Config.apps && Config.apps.kitty ? Config.apps.kitty.font : "", Config.theme.monoFont, "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"], root._families)
    readonly property real fontPixelSize: Math.round(((Config.apps && Config.apps.kitty ? Number(Config.apps.kitty.fontSize) : 11) || 11) * 4 / 3)
    property var _families: Qt.fontFamilies()
    // Some font has the Nerd Font icons (patched or "Symbols Nerd Font";
    // fontconfig falls back to it in kitty). The Qt font list is read once,
    // so a font installed from the catalog counts through its status.
    readonly property bool nerdFontAvailable: TermModel.hasNerdFont(root._families) || ExtrasService.cardState("nerd-font") === "installed"

    property bool _loaded: false
    // keys asked for (re-fetched after an invalidation), keys in flight
    property var _wanted: ({})
    property var _pending: ({})
    property int _generation: 0
    // "Make fish my default shell" waits for the fish install to finish.
    property bool _chshAfterInstall: false
    // A prompt switched on before term.status arrived: its engine check
    // waits for the status instead of being dropped.
    property bool _engineAfterStatus: false
    property string _paletteSig: ""
    property string _enginesSig: ""

    // fish as found on PATH (NixOS: /run/current-system/sw/bin/fish), the
    // path chsh validates against /etc/shells.
    readonly property string fishPath: root.status?.fishPath || "/usr/bin/fish"

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
            BackendService.call("term.fetch.presets", {}, (result, error) => {
                if (!error && result)
                    root.fetchPresets = result;
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
        const sig = (inst.starship ? "s" : "-") + (inst.ohmyposh ? "o" : "-") + (st.greeting && st.greeting.fastfetchInstalled ? "f" : "-");
        if (root._enginesSig !== "" && sig !== root._enginesSig)
            root.invalidate();
        root._enginesSig = sig;
        if (root._chshAfterInstall && st.fishInstalled) {
            root._chshAfterInstall = false;
            ExtrasService.setLoginShell(root.fishPath);
        }
        if (root._engineAfterStatus && st.engineInstalled) {
            root._engineAfterStatus = false;
            root.ensureEngine();
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
        Object.keys(root._wantedFetch).forEach(key => root._queueFetch(key));
    }

    // Greeting preview of a look + logo (undefined until it arrives; read
    // fetchPreviews in bindings, call ensureFetch() once).
    function ensureFetch(preset, logo, path) {
        if (!preset)
            return;
        const key = FetchModel.previewKey(preset, logo, path);
        if (!root._wantedFetch[key]) {
            const w = Object.assign({}, root._wantedFetch);
            w[key] = {
                "preset": preset,
                "logo": logo,
                "logoPath": path || ""
            };
            root._wantedFetch = w;
        }
        if (root.fetchPreviews[key] === undefined)
            root._queueFetch(key);
    }

    // Like _queue: Qt.callLater keeps only the last call of a function.
    property var _fetchQueued: []
    function _queueFetch(key) {
        if (root._fetchQueued.indexOf(key) < 0)
            root._fetchQueued.push(key);
        Qt.callLater(root._drainFetch);
    }
    function _drainFetch() {
        const keys = root._fetchQueued;
        root._fetchQueued = [];
        keys.forEach(key => root._fetchGreeting(key));
    }

    function _fetchGreeting(key) {
        const want = root._wantedFetch[key];
        if (!want || root._pending["fetch:" + key])
            return;
        root._pending["fetch:" + key] = true;
        const gen = root._generation;
        const params = Object.assign({}, want);
        const ansi = FetchModel.ansiTable(Colors, Colors.background.hslLightness < 0.5);
        if (ansi.length === 16)
            params.ansi = ansi;
        BackendService.call("term.fetch.preview", params, (result, error) => {
            if (gen !== root._generation)
                return;
            delete root._pending["fetch:" + key];
            if (error || !result)
                return;
            const next = Object.assign({}, root.fetchPreviews);
            next[key] = result;
            root.fetchPreviews = next;
        });
    }

    // fastfetch through the extras queue (the greeting is silent until it
    // is installed).
    function installFastfetch() {
        if (ExtrasService.cardState("fastfetch") === "selectable")
            ExtrasService.install(["fastfetch"]);
    }

    // The user switched the greeting on in this version (Settings, the
    // wizard): it may add its line to ~/.bashrc / ~/.zshrc from now on. A
    // greeting on from before the update stays in fish until then.
    function allowGreetingShells() {
        BackendService.call("term.fetch.allow", {}, (result, error) => {
            if (!error && result)
                root._setStatus(result);
        });
    }

    // The wizard turns the greeting on with a look: written like
    // enablePrompt, fastfetch queued when it is missing.
    function enableGreeting(preset, logo) {
        if (!Config.terminal)
            return;
        DryRun.journal("enable the fastfetch greeting (" + preset + ", " + logo + ")");
        root.allowGreetingShells();
        Config.terminal.fastfetchPreset = preset;
        Config.terminal.fastfetchLogo = logo;
        Config.terminal.greeting = "fastfetch";
        Config.saveTerminal();
        if (root.greeting && !root.greeting.fastfetchInstalled)
            root.installFastfetch();
    }

    // The user picked prompt `id`: switch it on (an existing prompt is only
    // replaced once the user picks one) and queue the engine when it is
    // missing. Every UI that turns the prompt on (settings gallery,
    // onboarding) calls this instead of writing terminal.prompt/enabled,
    // so the engine install is never skipped.
    function enablePrompt(id) {
        if (!Config.terminal)
            return;
        DryRun.journal("enable prompt " + id + " (" + root.engine + ")");
        Config.terminal.prompt = id;
        Config.terminal.enabled = true;
        Config.saveTerminal();
        root.ensureEngine();
    }

    // The prompt is on: queue its engine when it is missing (the hook only
    // runs an installed engine, so nothing breaks meanwhile). Called from
    // user actions only (enablePrompt, the settings toggle and engine switch),
    // never from config changes made elsewhere.
    function ensureEngine() {
        const st = root.status;
        if (!st || !st.engineInstalled) {
            // Not known yet (a card clicked before term.status came back):
            // decide once it arrives.
            if (!root._engineAfterStatus) {
                root._engineAfterStatus = true;
                root.refreshStatus();
            }
            return;
        }
        if (!Config.terminal || !Config.terminal.enabled || st.engineInstalled[root.engine])
            return;
        if (ExtrasService.cardState(TermModel.engineExtra(root.engine)) !== "installing")
            root.installEngine(root.engine);
    }

    function installEngine(engine) {
        ExtrasService.install(root.withFastfetch([TermModel.engineExtra(engine)]));
    }

    // The terminal setup brings fastfetch along (the greeting runs it) when
    // the catalog reports it missing here; an unknown or unavailable state
    // adds nothing, since one unavailable id refuses the whole request.
    function withFastfetch(ids) {
        const st = ExtrasService.status["fastfetch"];
        return st && st.state === "missing" && ExtrasService.cardState("fastfetch") === "selectable" ? ids.concat(["fastfetch"]) : ids;
    }

    // Install fish when needed, then make it the login shell (chsh through
    // the backend, asks for the password).
    function makeFishDefault() {
        if (root.fishInstalled) {
            ExtrasService.setLoginShell(root.fishPath);
            return;
        }
        root._chshAfterInstall = true;
        ExtrasService.install(root.withFastfetch(["fish"]));
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

    // Installs (fastfetch: the greeting preview turns real) and the login
    // shell change what `term.status` reports.
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
        function onFastfetchPresetChanged() {
            root.apply();
        }
        function onFastfetchLogoChanged() {
            root.apply();
        }
        function onFastfetchLogoPathChanged() {
            root.apply();
        }
    }

    Component.onCompleted: root._paletteSig = String(Colors.primary) + String(Colors.secondary) + String(Colors.tertiary) + String(Colors.background) + String(Colors.surfaceContainerHigh)
}
