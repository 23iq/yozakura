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
// the preset choice, the keybind tour and the voice setup job. Settings go
// through SettingsStore (live preview; staged domains are applied when the
// wizard ends).
QtObject {
    id: root

    property int index: 0
    readonly property var step: Steps.at(index)
    readonly property int count: Steps.count()
    readonly property bool isFirst: Steps.isFirst(index)
    readonly property bool isLast: Steps.isLast(index)
    // +1 forward, -1 back: steps slide in from that side.
    property int direction: 1

    signal finished

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
