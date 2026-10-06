pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.extras
import "TermModel.js" as TermModel

// Terminal look, shared by Settings > Terminal & Apps and onboarding: the
// live kitty preview of the chosen prompt, what keeps it from being exact
// (engine missing), fish status (installed, login shell, another prompt in
// config.fish) and the prompt gallery.
Column {
    id: root

    property bool animate: true

    readonly property var term: Config.terminal
    readonly property string engine: TerminalLookService.engine
    readonly property string prompt: TerminalLookService.prompt
    readonly property var preview: TerminalLookService.previews[TermModel.previewKey(root.engine, root.prompt)]
    readonly property var approx: TermModel.approxNotice(root.preview)
    readonly property var status: TerminalLookService.status
    readonly property string fish: TermModel.fishState(root.status)
    readonly property bool promptOn: !!(root.term && root.term.enabled)
    readonly property var presetInfo: TerminalLookService.presets.find(p => p.id === root.prompt) ?? null
    readonly property bool needsNerdFont: !!root.presetInfo && root.presetInfo.nerdFont && !TerminalLookService.nerdFontAvailable
    readonly property string engineExtra: TermModel.engineExtra(root.engine)
    readonly property bool engineInstalling: root.promptOn && root.installing(root.engineExtra)
    readonly property var engineProgress: ExtrasService.progress[root.engineExtra] ?? null

    spacing: 12

    function _ensure() {
        TerminalLookService.ensure(root.prompt, root.engine);
    }
    onEngineChanged: root._ensure()
    onPromptChanged: root._ensure()
    Component.onCompleted: {
        TerminalLookService.load();
        root._ensure();
    }

    function installing(id) {
        return ExtrasService.cardState(id) === "installing";
    }

    // Switching the prompt on or changing its engine here queues a missing
    // engine; config changes from elsewhere never install anything.
    Connections {
        target: SettingsStore
        function onValueSet(key, value) {
            if ((key === "terminal.enabled" && value === true) || key === "terminal.engine")
                TerminalLookService.ensureEngine();
        }
    }

    TerminalPreview {
        objectName: "terminalPreview"
        width: root.width
        preview: root.preview
        fontFamily: TerminalLookService.fontFamily
        pixelSize: TerminalLookService.fontPixelSize
        padding: root.term ? Number(root.term.padding) : 12
        cursorShape: root.term ? root.term.cursorShape : "beam"
        cursorBlink: root.term ? root.term.cursorBlink : true
        greeting: !!root.term && root.term.greeting === "fastfetch"
        backgroundOpacity: Glass.terminalOpacity
        animate: root.animate
    }

    LookNotice {
        objectName: "approxNotice"
        width: root.width
        visible: root.approx !== null && !root.engineInstalling
        icon: "info"
        title: I18n.t("prefs.term.look.approx.title")
        message: root.approx ? I18n.t(root.approx.reason) : ""

        PillButton {
            objectName: "installEngineButton"
            visible: !!root.approx && root.approx.install !== ""
            readonly property bool busy: !!root.approx && root.installing(root.approx.install)
            enabled: !busy
            kind: "filled"
            icon: busy ? "" : "downloadSimple"
            text: busy ? I18n.t("prefs.term.look.installing") : I18n.t("prefs.term.look.install_engine", root.approx ? ExtrasService.displayName(root.approx.install) : "")
            onClicked: TerminalLookService.installEngine(root.engine)
        }
    }

    LookNotice {
        objectName: "engineNotice"
        width: root.width
        visible: root.engineInstalling
        icon: "downloadSimple"
        title: I18n.t("prefs.term.look.engine_queued", ExtrasService.displayName(root.engineExtra))
        message: root.engineProgress && root.engineProgress.phase ? root.engineProgress.phase : I18n.t("prefs.term.look.engine_queued.desc")

        ProgressTrack {
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            height: 6
            percent: root.engineProgress && root.engineProgress.percent !== undefined ? root.engineProgress.percent : -1
        }
    }

    LookNotice {
        objectName: "nerdNotice"
        width: root.width
        visible: root.needsNerdFont
        tone: "warning"
        icon: "textAa"
        title: I18n.t("prefs.term.look.nerd.title")
        message: I18n.t("prefs.term.look.nerd.desc")

        PillButton {
            objectName: "usePlainButton"
            kind: "tonal"
            text: I18n.t("prefs.term.look.nerd.use_plain")
            onClicked: TerminalLookService.choose("plain")
        }
        PillButton {
            objectName: "installNerdButton"
            readonly property bool busy: root.installing("nerd-font")
            enabled: !busy
            kind: "filled"
            icon: busy ? "" : "downloadSimple"
            text: busy ? I18n.t("prefs.term.look.installing") : I18n.t("prefs.term.look.nerd.install")
            onClicked: ExtrasService.install(["nerd-font"])
        }
    }

    LookNotice {
        objectName: "offNotice"
        width: root.width
        visible: !root.promptOn
        icon: "info"
        title: I18n.t("prefs.term.look.off.title")
        message: I18n.t("prefs.term.look.off.desc")
    }

    LookNotice {
        objectName: "fishNotice"
        width: root.width
        visible: root.fish === "missing" || root.fish === "notLogin"
        tone: "warning"
        icon: "terminal"
        title: I18n.t(root.fish === "missing" ? "prefs.term.look.fish.missing" : "prefs.term.look.fish.not_login")
        message: I18n.t("prefs.term.look.fish.desc")

        PillButton {
            objectName: "makeFishButton"
            readonly property bool busy: root.installing("fish")
            enabled: !busy
            kind: "filled"
            text: busy ? I18n.t("prefs.term.look.installing") : I18n.t("prefs.term.look.fish.make_default")
            onClicked: TerminalLookService.makeFishDefault()
        }
    }

    LookNotice {
        objectName: "foreignNotice"
        width: root.width
        visible: !!root.status && !!root.status.foreignPromptInit
        tone: "warning"
        icon: "warning"
        title: I18n.t("prefs.term.look.foreign.title", root.status && root.status.foreignFile ? root.status.foreignFile.replace(/^.*\/\.config\//, "~/.config/") : "config.fish")
        message: I18n.t("prefs.term.look.foreign.desc")
    }

    PromptGallery {
        objectName: "promptGallery"
        width: root.width
    }
}
