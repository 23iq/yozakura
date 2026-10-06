import QtQuick
import Quickshell.Io
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
import "OnboardingSteps.js" as Steps
import "OnboardingModel.js" as Model

// Wizard state shared by the steps: navigation, terminal detection, the
// preset choice, the keybind tour, the installs queued from the wizard and
// the exclusive-mode choice (applied on finish). Owned by
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
    // Installs keep running in the backend queue.
    function finish() {
        if (SettingsStore.hasChanges)
            SettingsStore.apply();
        finished();
    }

    // "Start using" and the summary's Settings links: finish and apply the
    // only-shell choice (Skip / Esc never do). A failure surfaces as a
    // notification: the wizard is gone by then.
    function start() {
        if (isLast && wantsExclusive)
            ExclusiveService.enable(ok => {
                if (!ok)
                    Notifications.notifyInternal({
                        "summary": I18n.t("onboarding.finish.exclusive.failed", Brand.displayName),
                        "body": I18n.t("onboarding.finish.exclusive.failed.body", ExclusiveService.error),
                        "appName": Brand.displayName,
                        "urgency": "critical"
                    });
            });
        finish();
    }

    // ---- installs and exclusive mode ---------------------------------------
    // Every catalog id queued while the wizard is open (apps, agents, voice).
    readonly property var installs: choices.installs || []
    property Connections _extras: Connections {
        target: ExtrasService
        function onQueued(ids) {
            const all = root.installs.slice();
            ids.forEach(id => {
                if (!all.includes(id))
                    all.push(id);
            });
            root.remember("installs", all);
        }
    }
    readonly property bool exclusiveOffered: ExclusiveService.supported && ExclusiveService.status.compositor === "hyprland" && !ExclusiveService.active
    readonly property bool wantsExclusive: choices.exclusive === true && exclusiveOffered && ExclusiveService.blocked === ""

    // ---- detection -------------------------------------------------------
    property var detected: Model.parseDetect("")
    readonly property bool detecting: detectProc.running && !detected.complete
    property Process detectProc: Process {
        command: ["bash", "-c", Model.detectScript()]
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
}
