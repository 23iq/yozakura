pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.displays
import qs.config
import "../services/DisplayModel.js" as DisplayModel
import "../services/KeyboardModel.js" as KeyboardModel

// Displays + keyboard: one card per monitor (best refresh rate in one click,
// recommended scale, the full editor under "More") and the keyboard layouts,
// pre-filled from the system locale on the first visit. A monitor change
// runs live: the wizard steps aside for the "Keep these display settings?"
// prompt (OnboardingWindow) and keeping it saves the layout.
Item {
    id: root

    property OnboardingState wizard
    property string error: ""

    readonly property var outputs: DisplaysService.outputs.filter(o => o.enabled !== false)

    // Live configs with `config` in place of its monitor, re-arranged so a
    // new size never overlaps a neighbour.
    function applyMonitor(config) {
        error = "";
        const others = DisplaysService.currentConfigs().filter(c => c.name !== config.name);
        if (config.enabled === false && !others.some(c => c.enabled !== false))
            return;
        const list = DisplayModel.arrange(others.concat([config]), config.name, config.x, config.y);
        DisplaysService.apply(list);
        root._candidate = config;
    }

    // The monitor change waiting for "Keep"; remembered once it is kept.
    property var _candidate: null

    function _sessionEnded(state) {
        const c = root._candidate;
        root._candidate = null;
        if (!c || state !== "kept")
            return;
        const modes = Object.assign({}, wizard.choices.displays || {});
        modes[c.name] = {
            "width": c.width,
            "height": c.height,
            "refresh": c.refresh,
            "scale": c.scale
        };
        wizard.remember("displays", modes);
    }

    // First visit: `us` + the locale's layout, unless layouts were set
    // before. The marker is persistent (not a wizard choice): a skipped or
    // finished setup never re-seeds. Retried until config and state load.
    readonly property string seededKey: "onboarding.keyboardSeeded"

    function seedKeyboard(locale) {
        if (!wizard || !Config.keyboardReady || !StateService.initialized || StateService.get(root.seededKey, false) === true)
            return;
        StateService.set(root.seededKey, true);
        const cur = Array.from(Config.keyboard.layouts);
        const untouched = cur.length === 1 && cur[0].layout === "us" && !cur[0].variant;
        if (!untouched)
            return;
        const codes = KeyboardModel.defaultsForLocale(locale);
        if (codes.length < 2)
            return;
        Config.keyboard.layouts = codes.map(c => ({
                    "layout": c,
                    "variant": ""
                }));
        Config.saveKeyboard();
        wizard.remember("keyboard", codes);
    }

    Component.onCompleted: {
        DisplaysService.refresh();
        seedKeyboard(Qt.locale().name);
    }

    Connections {
        target: Config
        function onKeyboardReadyChanged() {
            root.seedKeyboard(Qt.locale().name);
        }
    }

    Connections {
        target: StateService
        function onInitializedChanged() {
            root.seedKeyboard(Qt.locale().name);
        }
    }

    Connections {
        target: DisplaysService
        function onApplyFailed(message) {
            root.error = message;
            root._candidate = null;
        }
        function onSessionChanged() {
            if (DisplaysService.session.state !== "pending")
                root._sessionEnded(DisplaysService.session.state);
        }
    }

    Flickable {
        id: flick
        objectName: "displaysFlick"
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Column {
            id: column
            width: flick.width - 12
            spacing: Math.round(Styling.fontSize(0) * 0.9)

            SectionLabel {
                width: parent.width
                icon: "monitor"
                text: I18n.t("onboarding.displays.monitors")
                hint: root.outputs.length > 0 ? I18n.t("onboarding.displays.monitors.desc") : I18n.t("onboarding.displays.none")
            }

            DisplayNotice {
                objectName: "displayError"
                width: parent.width
                visible: root.error !== ""
                tone: "error"
                icon: "warning"
                title: I18n.t("prefs.displays.apply_failed")
                message: root.error
            }

            DisplayPendingNote {
                objectName: "deferredNote"
                width: parent.width
                visible: DisplaysService.pending && !DisplaysService.session.live
            }

            Repeater {
                model: root.outputs

                delegate: MonitorUpgradeCard {
                    required property var modelData
                    objectName: "monitorCard:" + modelData.name
                    width: column.width
                    output: modelData
                    busy: DisplaysService.pending
                    onApply: config => root.applyMonitor(config)
                }
            }

            Item {
                width: 1
                height: Math.round(Styling.fontSize(0) * 0.4)
            }

            KeyboardSetupCard {
                objectName: "keyboardCard"
                width: parent.width
                wizard: root.wizard
            }
        }
    }
}
