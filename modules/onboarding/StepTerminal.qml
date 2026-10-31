pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.terminal
import qs.modules.components.kit
import qs.config
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
    readonly property var terminals: Model.terminalChoices(detected, terminal)
    readonly property var term: Config.terminal
    readonly property var preview: TerminalLookService.previews[TermModel.previewKey(TerminalLookService.engine, TerminalLookService.prompt)]
    readonly property string fish: TermModel.fishState(TerminalLookService.status)
    readonly property bool fishBusy: ExtrasService.cardState("fish") === "installing"
    // installing fish or the login-shell change failed: the request did not happen
    readonly property var loginJobs: Object.values(ExtrasService.jobs || {}).filter(j => j && j.kind === "login")
    readonly property bool fishFailed: !root.fishBusy && !root.loginJobs.some(j => j.state === "queued" || j.state === "running") && (ExtrasService.cardState("fish") === "failed" || root.loginJobs.some(j => j.state === "failed"))
    readonly property var presetInfo: TerminalLookService.presets.find(p => p.id === TerminalLookService.prompt) ?? null
    readonly property bool needsNerdFont: !!presetInfo && presetInfo.nerdFont && !TerminalLookService.nerdFontAvailable
    readonly property bool nerdInstallable: ExtrasService.cardState("nerd-font") !== "unavailable"
    readonly property int gap: Space.xl

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
            x: Space.stroke
            width: flick.width - Space.m
            spacing: root.gap

            // ---- terminal app + preview on desktop ------------------------
            Item {
                width: parent.width
                height: Math.max(apps.implicitHeight, peekBox.implicitHeight)

                Group {
                    id: apps
                    width: Math.round((parent.width - root.gap) * 0.54)
                    label: I18n.t("onboarding.system.terminal")

                    Flow {
                        id: chips
                        objectName: "terminalChips"
                        width: parent.width
                        spacing: Space.s

                        signal selected(string value)
                        onSelected: value => root.pickTerminal(value)

                        Repeater {
                            model: root.terminals
                            delegate: FocusChip {
                                required property string modelData
                                objectName: "terminalChip:" + modelData
                                text: modelData
                                active: modelData === root.terminal
                                onClicked: chips.selected(modelData)
                            }
                        }

                        // "Other…": any terminal command, Enter applies it.
                        Item {
                            width: Space.px(160)
                            height: Space.chip

                            Rectangle {
                                anchors.fill: parent
                                radius: Look.chipRadius(height)
                                color: Look.raisedFill(otherHover.hovered)
                                border.width: Look.controlEdge.a > 0 ? Space.hairline : 0
                                border.color: Look.controlEdge
                            }

                            HoverHandler {
                                id: otherHover
                                cursorShape: Qt.IBeamCursor
                            }

                            InlineEdit {
                                id: otherInput
                                objectName: "terminalOther"
                                anchors.fill: parent
                                anchors.leftMargin: Space.m
                                anchors.rightMargin: Space.m
                                role: "secondary"
                                autoFocus: false
                                activeFocusOnTab: true
                                onAccepted: {
                                    root.pickTerminal(text);
                                    text = "";
                                }

                                KitText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: otherInput.text === "" && !otherInput.activeFocus
                                    role: "secondary"
                                    color: Type.muted
                                    text: I18n.t("onboarding.terminal.other")
                                }
                            }

                            FocusRing {
                                shown: otherInput.activeFocus
                                radius: Look.chipRadius(height) + Space.stroke
                            }
                        }
                    }

                    KitText {
                        visible: !!root.wizard && root.wizard.detecting
                        role: "caption"
                        text: I18n.t("onboarding.detecting")
                    }
                }

                Column {
                    id: peekBox
                    anchors.right: parent.right
                    spacing: Space.xs
                    PeekButton {
                        objectName: "terminalPeek"
                        anchors.right: parent.right
                    }
                    KitText {
                        anchors.right: parent.right
                        role: "caption"
                        text: I18n.t("onboarding.terminal.peek_hint", root.terminal || "kitty")
                    }
                }
            }

            // ---- live preview + prompt gallery ------------------------------
            Item {
                id: body
                width: parent.width
                // fills the step; the gallery scrolls inside it
                height: Math.max(previewCol.implicitHeight, flick.height - y)

                Group {
                    id: previewCol
                    width: Math.round((parent.width - root.gap) * 0.54)
                    label: I18n.t("onboarding.terminal.prompt")

                    KitText {
                        width: parent.width
                        role: "secondary"
                        wrapMode: Text.WordWrap
                        text: I18n.t("onboarding.terminal.prompt.desc")
                    }

                    TerminalPreview {
                        objectName: "onboardingTerminalPreview"
                        width: parent.width
                        preview: root.preview
                        fontFamily: TerminalLookService.fontFamily
                        pixelSize: TerminalLookService.fontPixelSize
                        padding: root.term ? Number(root.term.padding) : Space.m
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
                        checked: root.fish === "ok" || (!!root.wizard && root.wizard.choices.fishDefault === true && !root.fishFailed)
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

                        FocusChip {
                            text: I18n.t("prefs.term.look.nerd.use_plain")
                            onClicked: TerminalLookService.enablePrompt("plain")
                        }
                        FocusChip {
                            visible: root.nerdInstallable
                            readonly property bool busy: ExtrasService.cardState("nerd-font") === "installing"
                            enabled: !busy
                            icon: busy ? "" : Icons.downloadSimple
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
                        width: galleryFlick.width - Space.m
                    }
                }
            }
        }
    }
}
