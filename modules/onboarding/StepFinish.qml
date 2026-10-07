pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "FinishModel.js" as Finish

// Done: a summary of the setup (one card per area, live install progress),
// on Hyprland the "only shell" choice, links to Settings and the big
// "Start using" button. Installs keep running in the backend after the
// wizard closes.
Item {
    id: root

    property OnboardingState wizard

    readonly property var split: Finish.splitInstalls(wizard ? wizard.installs : [], ExtrasService.catalog)
    readonly property var apps: Finish.installSummary(root.split.apps, ExtrasService.status, ExtrasService.progress)
    readonly property var ai: Finish.installSummary(root.split.ai, ExtrasService.status, ExtrasService.progress)
    readonly property string voiceState: ExtrasService.cardState("voice")
    readonly property var voiceProgress: ExtrasService.progress["voice"] ?? null
    readonly property bool installing: ExtrasService.busy
    readonly property bool compact: height < 560

    // "2 installed · 1 failed · 1 installing"
    function installLine(s, none) {
        if (s.total === 0)
            return none;
        const parts = [];
        if (s.installed > 0)
            parts.push(I18n.tn("onboarding.finish.installed_n", s.installed));
        if (s.failed > 0)
            parts.push(I18n.tn("onboarding.finish.failed_n", s.failed));
        if (s.installing > 0)
            parts.push(I18n.tn("onboarding.finish.installing_n", s.installing));
        return parts.length > 0 ? parts.join(" · ") : none;
    }

    readonly property var cards: {
        const w = root.wizard;
        if (!w)
            return [];
        const term = String(w.get("general.terminal") || "");
        const preset = TerminalLookService.presets.find(p => p.id === Config.terminal.prompt);
        const prompt = Config.terminal.enabled && preset ? preset.name : "";
        const aiNames = Finish.installedAi(ExtrasService.catalog, ExtrasService.status);
        return [
            {
                "id": "displays",
                "icon": "monitor",
                "label": I18n.t("onboarding.finish.displays"),
                "value": Finish.displaysLine(DisplaysService.currentConfigs()) || I18n.t("onboarding.finish.unchanged")
            },
            {
                "id": "keyboard",
                "icon": "keyboard",
                "label": I18n.t("onboarding.keyboard.title"),
                "value": Finish.layoutsLine(KeyboardService.effective.layouts) || "US"
            },
            {
                "id": "look",
                "icon": "palette",
                "label": I18n.t("onboarding.finish.preset"),
                "value": w.chosenPreset !== "" ? w.chosenPreset : I18n.t("onboarding.finish.look_current")
            },
            {
                "id": "terminal",
                "icon": "terminal",
                "label": I18n.t("onboarding.terminal.title"),
                "value": [term, prompt].filter(s => s !== "").join(" · ")
            },
            {
                "id": "apps",
                "icon": "squaresFour",
                "label": I18n.t("onboarding.apps.title"),
                "value": root.installLine(root.apps, I18n.t("onboarding.finish.apps_none")),
                "busy": root.apps.installing > 0,
                "percent": root.apps.percent,
                "muted": root.apps.total === 0
            },
            {
                "id": "ai",
                "icon": "sparkle",
                "label": I18n.t("onboarding.finish.ai"),
                "value": w.get("ai.enabled") === false ? I18n.t("onboarding.off") : (root.ai.installing > 0 ? root.installLine(root.ai, "") : (aiNames.length > 0 ? aiNames.join(", ") : I18n.t("onboarding.finish.ai_cloud"))),
                "busy": root.ai.installing > 0,
                "percent": root.ai.percent,
                "muted": w.get("ai.enabled") === false
            },
            {
                "id": "voice",
                "icon": "mic",
                "label": I18n.t("onboarding.finish.voice"),
                "value": root.voiceState === "installed" ? I18n.t("onboarding.finish.voice_ready") : (root.voiceState === "installing" ? I18n.t("onboarding.finish.voice_installing") : I18n.t("onboarding.finish.voice_off")),
                "busy": root.voiceState === "installing",
                "percent": root.voiceProgress && root.voiceProgress.state === "running" ? root.voiceProgress.percent : -1,
                "muted": root.voiceState !== "installed" && root.voiceState !== "installing"
            }
        ];
    }

    function openSettings(category) {
        if (category !== "")
            GlobalStates.settingsCategory = category;
        root.wizard.start();
        if (!GlobalStates.settingsWindowVisible)
            GlobalShortcuts.toggleSettings();
    }

    Component.onCompleted: {
        ExtrasService.load();
        TerminalLookService.load();
        if (ExclusiveService.supported)
            ExclusiveService.refresh();
    }

    // the cards in rows of `columns`, the last row centred
    readonly property int columns: width >= 840 ? 4 : (width >= 600 ? 3 : 2)
    readonly property var rows: {
        const out = [];
        for (let i = 0; i < root.cards.length; i += root.columns)
            out.push(root.cards.slice(i, i + root.columns));
        return out;
    }

    Flickable {
        id: flick
        objectName: "finishFlick"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: actions.top
        anchors.bottomMargin: 14
        contentWidth: width
        contentHeight: Math.max(height, column.implicitHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: column.implicitHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        Column {
            id: column
            width: Math.min(flick.width - 12, 1000)
            x: (flick.width - width) / 2
            y: Math.max(0, (flick.height - implicitHeight) / 2)
            topPadding: 6
            spacing: Math.round(Styling.fontSize(0) * (root.compact ? 1 : 1.4))

            // ---- hero --------------------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                SakuraLogo {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: root.compact ? 52 : Math.min(88, Math.round(root.height * 0.12))
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.t("onboarding.finish.title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(root.compact ? 9 : 12)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: I18n.t("onboarding.finish.subtitle")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(1)
                    color: Colors.overSurfaceVariant
                }
            }

            // ---- summary -----------------------------------------------------
            Column {
                id: grid
                objectName: "summaryGrid"
                width: parent.width
                spacing: 12
                readonly property real cell: Math.floor((width - (root.columns - 1) * 12) / root.columns)

                Repeater {
                    model: root.rows
                    delegate: Row {
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12
                        Repeater {
                            model: parent.modelData
                            delegate: SummaryCard {
                                required property var modelData
                                objectName: "summary:" + modelData.id
                                width: grid.cell
                                icon: modelData.icon
                                label: modelData.label
                                value: modelData.value
                                busy: modelData.busy === true
                                percent: modelData.percent ?? -1
                                muted: modelData.muted === true
                            }
                        }
                    }
                }
            }

            // ---- installs still running -------------------------------------
            Row {
                objectName: "backgroundNote"
                visible: root.installing
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.hourglass
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.primary
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("onboarding.finish.background")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.overSurfaceVariant
                }
            }

            // ---- Hyprland: the only shell -------------------------------------
            Loader {
                objectName: "exclusiveLoader"
                width: parent.width
                active: !!root.wizard && root.wizard.exclusiveOffered
                visible: active
                sourceComponent: ExclusiveChoice {
                    wizard: root.wizard
                    onExpanded: scrollEnd.restart()
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: I18n.t("onboarding.finish.again", Brand.appId + " onboarding")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.outline
            }
        }
    }

    NumberAnimation {
        id: scrollEnd
        target: flick
        property: "contentY"
        to: Math.max(0, flick.contentHeight - flick.height)
        duration: Config.animDuration
        easing.type: Motion.morph.easing
    }

    // ---- links + start: always in view ---------------------------------------
    Row {
        id: actions
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 10

        NavButton {
            objectName: "finishSpecials"
            anchors.verticalCenter: parent.verticalCenter
            kind: "ghost"
            icon: "squaresFour"
            text: I18n.t("onboarding.finish.specials")
            onClicked: root.openSettings("specials")
        }
        NavButton {
            objectName: "finishStart"
            anchors.verticalCenter: parent.verticalCenter
            kind: "filled"
            icon: "checkCircle"
            width: implicitWidth + 36
            height: Math.round(implicitHeight * 1.2)
            text: I18n.t("onboarding.finish.start", Brand.displayName)
            onClicked: root.wizard.start()
        }
        NavButton {
            objectName: "finishOpenSettings"
            anchors.verticalCenter: parent.verticalCenter
            kind: "ghost"
            icon: "gear"
            text: I18n.t("onboarding.finish.open_settings")
            onClicked: root.openSettings("")
        }
    }
}
