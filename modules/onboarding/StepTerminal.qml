pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.terminal
import qs.modules.settings
import qs.modules.settings.keyboard
import qs.config
import "../settings/Ui.js" as Ui
import "../terminal/TermModel.js" as TermModel
import "OnboardingModel.js" as Model

// Terminal: which terminal app the shell opens (detected ones, or any other
// command: general.terminal), the fish prompt (gallery + live kitty
// preview) and fish as the login shell.
Item {
    id: root

    property OnboardingState wizard

    readonly property string terminal: wizard ? String(wizard.get("general.terminal") || "") : ""
    readonly property var detected: wizard ? wizard.detected.terminals : []
    readonly property var terminals: Model.terminalChoices(detected, terminal).map(t => ({
                "value": t,
                "label": t
            }))
    readonly property var term: Config.terminal
    readonly property var preview: TerminalLookService.previews[TermModel.previewKey(TerminalLookService.engine, TerminalLookService.prompt)]
    readonly property string fish: TermModel.fishState(TerminalLookService.status)
    readonly property bool fishBusy: ExtrasService.cardState("fish") === "installing"
    readonly property var presetInfo: TerminalLookService.presets.find(p => p.id === TerminalLookService.prompt) ?? null
    readonly property bool needsNerdFont: !!presetInfo && presetInfo.nerdFont && !TerminalLookService.nerdFontAvailable
    readonly property bool nerdInstallable: ExtrasService.cardState("nerd-font") !== "unavailable"
    readonly property int gap: Math.round(Styling.fontSize(0) * 1.4)

    function pickTerminal(name) {
        const t = String(name || "").trim();
        if (t === "")
            return;
        wizard.set("general.terminal", t);
        wizard.remember("terminal", t);
    }

    function makeFishDefault() {
        if (root.fish === "ok")
            return;
        TerminalLookService.makeFishDefault();
        wizard.remember("fishDefault", true);
    }

    Component.onCompleted: {
        TerminalLookService.load();
        TerminalLookService.ensure(TerminalLookService.prompt, TerminalLookService.engine);
    }

    Connections {
        target: root.term
        function onPromptChanged() {
            root.wizard.remember("prompt", root.term.prompt);
        }
    }

    Flickable {
        id: flick
        objectName: "terminalFlick"
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
            width: flick.width - 10
            spacing: root.gap

            // ---- terminal app + preview on desktop ------------------------
            Item {
                width: parent.width
                height: Math.max(apps.implicitHeight, peekBox.implicitHeight)

                Column {
                    id: apps
                    width: parent.width - peekBox.width - root.gap
                    spacing: 8

                    SectionLabel {
                        width: parent.width
                        icon: "terminalWindow"
                        text: I18n.t("onboarding.system.terminal")
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        KeyChips {
                            objectName: "terminalChips"
                            options: root.terminals
                            value: root.terminal
                            onSelected: t => root.pickTerminal(t)
                        }

                        StyledRect {
                            id: other
                            variant: "common"
                            enableShadow: false
                            width: Math.round(Styling.fontSize(0) * 10)
                            height: 34
                            radius: height / 2

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: otherInput.activeFocus ? 2 : 1
                                border.color: otherInput.activeFocus ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
                                z: 10
                            }

                            TextInput {
                                id: otherInput
                                objectName: "terminalOther"
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                selectionColor: Colors.primary
                                selectedTextColor: Colors.overPrimary
                                onAccepted: {
                                    root.pickTerminal(text);
                                    text = "";
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: otherInput.text === "" && !otherInput.activeFocus
                                    text: I18n.t("onboarding.terminal.other")
                                    font: otherInput.font
                                    color: Colors.overSurfaceVariant
                                }
                            }
                        }
                    }

                    Text {
                        visible: !!root.wizard && root.wizard.detecting
                        text: I18n.t("onboarding.detecting")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.outline
                    }
                }

                Column {
                    id: peekBox
                    anchors.right: parent.right
                    spacing: 6
                    PeekButton {
                        objectName: "terminalPeek"
                        anchors.right: parent.right
                    }
                    Text {
                        anchors.right: parent.right
                        text: I18n.t("onboarding.terminal.peek_hint", root.terminal || "kitty")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                    }
                }
            }

            // ---- live preview + prompt gallery ------------------------------
            Item {
                id: body
                width: parent.width
                // fills the step; the gallery scrolls inside it
                height: Math.max(previewCol.implicitHeight, flick.height - y)

                Column {
                    id: previewCol
                    width: Math.round((parent.width - root.gap) * 0.54)
                    spacing: 10

                    SectionLabel {
                        width: parent.width
                        icon: "sparkle"
                        text: I18n.t("onboarding.terminal.prompt")
                        hint: I18n.t("onboarding.terminal.prompt.desc")
                    }

                    TerminalPreview {
                        objectName: "onboardingTerminalPreview"
                        width: parent.width
                        preview: root.preview
                        fontFamily: TerminalLookService.fontFamily
                        pixelSize: TerminalLookService.fontPixelSize
                        padding: root.term ? Number(root.term.padding) : 12
                        cursorShape: root.term ? root.term.cursorShape : "beam"
                        cursorBlink: root.term ? root.term.cursorBlink : true
                        greeting: false
                        backgroundOpacity: Glass.terminalOpacity
                    }

                    ChoiceRow {
                        objectName: "fishDefault"
                        width: parent.width
                        mode: "toggle"
                        icon: "terminal"
                        enabled: root.fish !== "ok" && !root.fishBusy
                        checked: root.fish === "ok" || (!!root.wizard && root.wizard.choices.fishDefault === true)
                        title: I18n.t("onboarding.terminal.fish")
                        subtitle: I18n.t(root.fish === "ok" ? "onboarding.terminal.fish.ok" : (root.fish === "missing" ? "onboarding.terminal.fish.missing" : "onboarding.terminal.fish.desc"))
                        badge: root.fishBusy ? I18n.t("prefs.term.look.installing") : ""
                        onToggled: v => {
                            if (v)
                                root.makeFishDefault();
                        }
                    }

                    // Same cue as Settings > Terminal: the prompt needs a Nerd Font.
                    LookNotice {
                        objectName: "nerdNotice"
                        width: parent.width
                        visible: root.needsNerdFont
                        tone: "warning"
                        icon: "textAa"
                        title: I18n.t("prefs.term.look.nerd.title")
                        message: I18n.t("prefs.term.look.nerd.desc") + (root.nerdInstallable ? "" : " " + I18n.t("prefs.term.look.nerd.manual"))

                        PillButton {
                            kind: "tonal"
                            text: I18n.t("prefs.term.look.nerd.use_plain")
                            onClicked: TerminalLookService.enablePrompt("plain")
                        }
                        PillButton {
                            visible: root.nerdInstallable
                            readonly property bool busy: ExtrasService.cardState("nerd-font") === "installing"
                            enabled: !busy
                            kind: "filled"
                            icon: busy ? "" : "downloadSimple"
                            text: busy ? I18n.t("prefs.term.look.installing") : I18n.t("prefs.term.look.nerd.install")
                            onClicked: ExtrasService.install(["nerd-font"])
                        }
                    }
                }

                Flickable {
                    id: galleryFlick
                    objectName: "promptGalleryFlick"
                    anchors.left: previewCol.right
                    anchors.leftMargin: root.gap
                    anchors.right: parent.right
                    height: parent.height
                    contentWidth: width
                    contentHeight: gallery.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: galleryFlick.contentHeight > galleryFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    PromptGallery {
                        id: gallery
                        objectName: "onboardingPromptGallery"
                        width: galleryFlick.width - 12
                    }
                }
            }
        }
    }
}
