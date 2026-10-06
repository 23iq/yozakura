import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
import qs.config
import "OnboardingSteps.js" as Steps
import "OnboardingModel.js" as Model

// Wizard state shared by the steps: navigation, environment detection,
// the preset choice, the keybind tour and the voice setup job. Owned by
// OnboardingService, which persists `step id` + `choices` (StateService) so
// a shell reload or crash resumes the wizard where it was. Settings go
// through SettingsStore (live preview; staged domains are applied when the
// wizard ends).
QtObject {
    id: root

    property int index: 0
    readonly property var step: Steps.at(index)
    readonly property string stepId: step.id
    readonly property int count: Steps.count()
    readonly property bool isFirst: Steps.isFirst(index)
    readonly property bool isLast: Steps.isLast(index)
    // +1 forward, -1 back: steps slide in from that side.
    property int direction: 1

    // The "Skip setup?" confirmation is showing in the card.
    property bool skipRequested: false
    // Small persisted answers (keys are step-defined, values JSON-safe):
    // what earlier steps chose, visible again after a resume.
    property var choices: ({})

    signal finished

    function remember(key, value) {
        const c = Object.assign({}, choices);
        c[key] = value;
        choices = c;
    }

    // Back to a clean first-run state (the service reuses one instance).
    function reset() {
        direction = 1;
        index = 0;
        choices = ({});
        tour = ({});
        chosenPreset = "";
        initialPreset = "";
        skipRequested = false;
    }

    // Resume at a step id (unknown ids fall back to the first step).
    function restore(id, saved) {
        const i = Steps.indexOf(id);
        index = i < 0 ? 0 : i;
        choices = saved && typeof saved === "object" ? saved : ({});
        chosenPreset = choices.preset || "";
        if (choices.initialPreset !== undefined)
            initialPreset = choices.initialPreset;
    }

    function go(i) {
        const target = Steps.clamp(i);
        if (target === index)
            return;
        direction = target > index ? 1 : -1;
        index = target;
    }
    function next() {
        if (isLast)
            finish();
        else
            go(index + 1);
    }
    function back() {
        go(index - 1);
    }

    // Finish or skip: keep what was chosen so far (it is already live).
    function finish() {
        cancelVoiceSetup();
        if (SettingsStore.hasChanges)
            SettingsStore.apply();
        finished();
    }

    // ---- detection -------------------------------------------------------
    property var detected: Model.parseDetect("")
    readonly property bool detecting: detectProc.running && !detected.complete
    property Process detectProc: Process {
        command: ["bash", "-c", Model.detectScript(), "detect", Brand.dataDir]
        stdout: StdioCollector {
            onStreamFinished: root.applyDetect(text)
        }
    }
    function detect() {
        detectProc.running = true;
        probeOllama();
    }
    // Ollama server state (backend probe: lists models, loads none).
    property var ollamaProbe: null
    readonly property var ollama: Model.ollamaState(detected, ollamaProbe)
    function probeOllama() {
        const endpoint = Config.ai && Config.ai.ollama ? Config.ai.ollama.endpoint || "" : "";
        BackendService.call("providers.ollama.probe", {
            endpoint: endpoint
        }, (res, err) => {
            if (!err && res)
                root.ollamaProbe = res;
        });
    }
    function applyDetect(text) {
        detected = Model.parseDetect(text);
    }

    // ---- preset ----------------------------------------------------------
    // Active preset when the wizard opened ("" when none is recorded).
    property string initialPreset: ""
    // Preset picked in the gallery ("" = keep the current look).
    property string chosenPreset: ""
    function choosePreset(name) {
        if (name === chosenPreset)
            return;
        chosenPreset = name;
        remember("preset", name);
        if (name !== "")
            PresetsService.loadPreset(name);
        else if (initialPreset !== "")
            PresetsService.loadPreset(initialPreset);
    }

    // ---- settings --------------------------------------------------------
    function set(key, value) {
        SettingsStore.set(key, value);
    }
    function get(key) {
        return SettingsStore.get(key);
    }

    // ---- keybind tour ----------------------------------------------------
    // id -> "done" | "skipped" (absent: pending)
    property var tour: ({})
    readonly property bool tourComplete: Model.tourDone(tour)
    readonly property var activeTask: {
        for (let i = 0; i < Model.TOUR.length; i++) {
            if (!tour[Model.TOUR[i].id])
                return Model.TOUR[i];
        }
        return null;
    }
    function markTask(id, status) {
        const t = Object.assign({}, tour);
        t[id] = status;
        tour = t;
    }
    function resetTour() {
        tour = ({});
    }

    // ---- voice setup -----------------------------------------------------
    readonly property string voiceScript: decodeURIComponent(Qt.resolvedUrl("../../scripts/voice_setup.sh").toString().replace("file://", ""))
    readonly property bool voiceInstalled: detected.whisper.installed && detected.whisper.model
    readonly property bool voiceRunning: voiceProc.running
    property real voiceProgress: 0
    property string voiceLine: ""
    // "" | "running" | "done" | "failed" | "cancelled"
    property string voiceStatus: ""
    property bool _voiceCancelled: false

    function startVoiceSetup() {
        if (voiceProc.running)
            return;
        _voiceCancelled = false;
        voiceProgress = 0.02;
        voiceLine = "";
        voiceStatus = "running";
        voiceProc.running = true;
    }
    function cancelVoiceSetup() {
        if (!voiceProc.running)
            return;
        _voiceCancelled = true;
        voiceProc.running = false;
    }
    function _voiceOutput(line) {
        const p = Model.voiceProgress(line, voiceProgress);
        voiceProgress = p.progress;
        if (p.text !== "")
            voiceLine = p.text;
    }

    property Process voiceProc: Process {
        command: ["bash", root.voiceScript]
        stdout: SplitParser {
            onRead: data => root._voiceOutput(data)
        }
        stderr: SplitParser {
            onRead: data => root._voiceOutput(data)
        }
        onExited: code => {
            if (root._voiceCancelled)
                root.voiceStatus = "cancelled";
            else if (code === 0) {
                root.voiceStatus = "done";
                root.voiceProgress = 1;
                root.detect();
            } else
                root.voiceStatus = "failed";
        }
    }
}
