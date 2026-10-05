pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.keybinds
import qs.config
import "OnboardingModel.js" as Model

// Interactive keybind tour: each task shows the real bound keys; pressing
// them runs the action (compositor -> `<app> run <cmd>` -> GlobalShortcuts),
// whose commandRan signal completes the task. The wizard window then steps
// aside (OnboardingService.suspended) until the opened panel is closed.
Item {
    id: root

    property OnboardingState wizard

    readonly property var tour: wizard ? wizard.tour : ({})
    readonly property var active: wizard ? wizard.activeTask : null

    function keysFor(task) {
        void KeybindsStore.revision;
        return Model.findKeys(KeybindsStore.rows, Brand.action(task.action));
    }

    function complete(command) {
        for (let i = 0; i < Model.TOUR.length; i++) {
            const t = Model.TOUR[i];
            if (t.command === command && !root.tour[t.id]) {
                root.wizard.markTask(t.id, "done");
                stepAside.begin();
                return true;
            }
        }
        return false;
    }

    Connections {
        target: GlobalShortcuts
        function onCommandRan(command) {
            if (root.wizard)
                root.complete(command);
        }
    }

    // While a task's panel is open the wizard hides; it comes back once
    // nothing is open any more (or after a timeout, e.g. a compositor-native
    // overview the shell cannot see).
    QtObject {
        id: stepAside
        property int elapsed: 0
        function begin() {
            elapsed = 0;
            OnboardingService.suspended = true;
            watch.restart();
        }
        function panelOpen() {
            return Visibilities.currentActiveModule !== "" || GlobalStates.assistantVisible === true || GlobalStates.settingsWindowVisible === true;
        }
    }
    Timer {
        id: watch
        interval: 250
        repeat: true
        onTriggered: {
            stepAside.elapsed += interval;
            if ((stepAside.elapsed >= 1000 && !stepAside.panelOpen()) || stepAside.elapsed >= 120000) {
                stop();
                OnboardingService.suspended = false;
            }
        }
    }
    Component.onDestruction: {
        if (watch.running)
            OnboardingService.suspended = false;
    }

    Column {
        anchors.fill: parent
        spacing: 10

        Repeater {
            model: Model.TOUR
            delegate: TourTask {
                required property var modelData
                width: parent.width
                task: modelData
                keys: root.keysFor(modelData)
                status: root.tour[modelData.id] || ""
                active: root.active !== null && root.active.id === modelData.id
                onSkipRequested: root.wizard.markTask(modelData.id, "skipped")
                onTryRequested: GlobalShortcuts.run(modelData.command)
            }
        }

        Text {
            width: parent.width
            topPadding: 6
            horizontalAlignment: Text.AlignHCenter
            text: root.wizard && root.wizard.tourComplete ? I18n.t("onboarding.tour.all_done") : I18n.t("onboarding.tour.footer")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: root.wizard && root.wizard.tourComplete ? Colors.primary : Colors.outline
        }
    }
}
