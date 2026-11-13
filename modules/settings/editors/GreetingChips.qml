pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.terminal
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.controls
import "../../terminal/FetchModel.js" as FetchModel

// What a new terminal greets you with, as pictures of what it prints:
// "Off" (a bare prompt) and each fastfetch look (TerminalLookService.
// fetchPresets) drawn from its rendered preview, the current one ringed. A
// look turns the greeting on with it (one undo step) and queues fastfetch
// when it is missing; the stage's terminal shows it. The logo and the
// shells it runs in are in the full editor ("More").
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property bool on: SettingsStore.get("terminal.greeting") === "fastfetch"
    readonly property string preset: String(SettingsStore.get("terminal.fastfetchPreset") || "")
    readonly property string logo: String(SettingsStore.get("terminal.fastfetchLogo") || "")
    readonly property string logoPath: String(SettingsStore.get("terminal.fastfetchLogoPath") || "")
    readonly property var looks: [
        {
            "id": "",
            "name": I18n.t("prefs.common.off")
        }
    ].concat((TerminalLookService.fetchPresets || []).map(p => ({
                "id": p.id,
                "name": p.own ? I18n.t("term.fetch.preset.own") : p.name
            })))
    readonly property real cardH: root.fillHeight > 0 ? root.fillHeight - Space.s * 2 : Space.px(96)
    readonly property real cardW: Math.round(root.cardH * 1.25)

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : root.cardH + Space.s * 2

    function pick(id) {
        if (id === "") {
            SettingsStore.set("terminal.greeting", "none");
            return;
        }
        TerminalLookService.allowGreetingShells();
        SettingsStore.transaction("prefs.term.section.greeting", () => {
            SettingsStore.set("terminal.fastfetchPreset", id);
            SettingsStore.set("terminal.greeting", "fastfetch");
        });
        if (!TerminalLookService.fastfetchInstalled)
            TerminalLookService.installFastfetch();
    }

    Flickable {
        id: flick
        objectName: "greetingStrip"
        anchors.fill: parent
        contentWidth: row.width + Space.m * 2
        interactive: contentWidth > width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: row
            x: Space.m
            y: Space.s
            spacing: Space.m
            Repeater {
                model: root.looks
                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    readonly property var result: card.modelData.id === "" ? null : TerminalLookService.fetchPreviews[FetchModel.previewKey(card.modelData.id, root.logo, root.logoPath)]
                    objectName: "greeting:" + (modelData.id || "off")
                    width: root.cardW
                    previewHeight: root.cardH
                    inset: true
                    selected: card.modelData.id === "" ? !root.on : (root.on && root.preset === card.modelData.id)
                    title: card.modelData.name
                    onClicked: root.pick(card.modelData.id)
                    Component.onCompleted: if (card.modelData.id !== "")
                        TerminalLookService.ensureFetch(card.modelData.id, root.logo, root.logoPath)

                    Mark {
                        anchors.fill: parent
                        radius: 0
                        color: Colors.background
                    }
                    // what the terminal prints, as large as the picture allows
                    Item {
                        id: area
                        x: Space.s
                        y: Space.s
                        width: parent.width - Space.s * 2
                        height: parent.height * 0.66
                        clip: true
                        Column {
                            id: lines
                            scale: Math.min(1, area.width / Math.max(1, lines.implicitWidth), area.height / Math.max(1, lines.implicitHeight))
                            transformOrigin: Item.TopLeft
                            Repeater {
                                model: card.result && card.result.lines ? card.result.lines : []
                                delegate: PromptLine {
                                    required property var modelData
                                    spans: modelData
                                    fontFamily: TerminalLookService.fontFamily
                                    pixelSize: Type.size("caption")
                                    foreground: Colors.overSurface
                                }
                            }
                        }
                        // Off: the bare prompt
                        Row {
                            visible: card.modelData.id === ""
                            spacing: Space.xs
                            Mark {
                                width: area.width * 0.35
                                height: Space.s
                                color: Qt.alpha(Colors.overBackground, 0.55)
                            }
                            Mark {
                                width: Space.xs
                                height: Space.m
                                radius: 0
                                color: Colors.overBackground
                            }
                        }
                        // a look still rendering
                        Column {
                            visible: card.modelData.id !== "" && !card.result
                            spacing: Space.xs
                            Repeater {
                                model: [0.5, 0.8, 0.6, 0.7]
                                delegate: Mark {
                                    required property real modelData
                                    width: area.width * modelData
                                    height: Space.xs
                                    color: Qt.alpha(Colors.overBackground, 0.25)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    StripFade {
        flick: flick
    }
}
