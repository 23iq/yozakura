pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../terminal/TermModel.js" as TermModel
import "../../terminal/FetchModel.js" as FetchModel

// Stage of Terminal: a kitty window on the plain stage as the prompt and
// greeting are configured (the real TerminalPreview, by URL, built off the
// first frame): the prompt preset drawn by its engine (TerminalLookService
// previews), the fastfetch greeting on top when it is on, your font,
// padding, cursor shape and opacity. Held still (no blinking cursor at
// rest). What keeps the prompt from showing (it is off, fish is missing, a
// Nerd Font is missing) is a chip under the window.
Stage {
    id: stage
    objectName: "terminalStage"

    readonly property var term: Config.terminal
    readonly property bool promptOn: !!(stage.term && stage.term.enabled)
    readonly property var preview: TerminalLookService.previews[TermModel.previewKey(TerminalLookService.engine, TerminalLookService.prompt)]
    readonly property bool greetingOn: SettingsStore.get("terminal.greeting") === "fastfetch"
    readonly property var fetch: TerminalLookService.fetchPreviews[FetchModel.previewKey(String(SettingsStore.get("terminal.fastfetchPreset") || ""), String(SettingsStore.get("terminal.fastfetchLogo") || ""), String(SettingsStore.get("terminal.fastfetchLogoPath") || ""))]
    readonly property string fish: TermModel.fishState(TerminalLookService.status)
    readonly property var presetInfo: (TerminalLookService.presets || []).find(p => p.id === TerminalLookService.prompt) ?? null
    readonly property bool needsNerdFont: !!stage.presetInfo && stage.presetInfo.nerdFont && !TerminalLookService.nerdFontAvailable
    // the one thing in the way, if any: [icon, i18n key]
    readonly property var notice: !stage.promptOn ? ["info", "prefs.term.look.off.title"] : (stage.fish === "missing" ? ["warning", "prefs.term.look.fish.missing"] : (stage.needsNerdFont ? ["textAa", "prefs.term.look.nerd.title"] : null))

    stageHeight: Space.px(300)
    backdrop: false

    Component.onCompleted: {
        TerminalLookService.load();
        TerminalLookService.ensure(TerminalLookService.prompt, TerminalLookService.engine);
    }
    // the prompt turned on (here or beside the stage): its engine is
    // installed when missing
    Connections {
        target: SettingsStore
        function onValueSet(key, value) {
            if ((key === "terminal.enabled" && value === true) || key === "terminal.engine")
                TerminalLookService.ensureEngine();
        }
    }

    Loader {
        id: window
        objectName: "terminalWindow"
        anchors.fill: parent
        asynchronous: true
        source: Qt.resolvedUrl("../../terminal/TerminalPreview.qml")
        onLoaded: {
            item.animate = false;
            item.desktop = Qt.binding(() => !stage.calm);
            item.preview = Qt.binding(() => stage.preview);
            item.fontFamily = Qt.binding(() => TerminalLookService.fontFamily);
            item.pixelSize = Qt.binding(() => TerminalLookService.fontPixelSize);
            item.padding = Qt.binding(() => stage.term ? Number(stage.term.padding) : 12);
            item.cursorShape = Qt.binding(() => stage.term ? String(stage.term.cursorShape) : "beam");
            item.cursorBlink = false;
            item.greeting = Qt.binding(() => stage.greetingOn);
            item.greetingLines = Qt.binding(() => stage.fetch && stage.fetch.lines && stage.fetch.lines.length > 0 ? stage.fetch.lines : null);
            item.backgroundOpacity = Qt.binding(() => Glass.terminalOpacity);
        }
    }

    StageSpot {
        anchors.fill: window
        anchors.margins: Space.l
        keys: ["terminal.prompt", "terminal.enabled", "terminal.greeting", "terminal.fastfetchPreset", "terminal.cursorShape", "terminal.cursorBlink"]
    }

    Chip {
        objectName: "terminalNotice"
        visible: stage.notice !== null
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Space.m
        dense: true
        icon: stage.notice ? (Icons[stage.notice[0]] ?? "") : ""
        text: stage.notice ? I18n.t(stage.notice[1]) : ""
        // the prompt off: turn it on; anything else: the full prompt view
        // (in "More") with the action that fixes it
        onClicked: {
            if (!stage.promptOn)
                SettingsStore.set("terminal.enabled", true);
            else
                SettingsStore.navigate("terminal", "promptmore", "terminal.lookFull");
        }
    }
}
