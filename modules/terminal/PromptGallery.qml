pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import "TermModel.js" as TermModel

// Prompt presets as cards: each shows its real prompt line (rendered by the
// engine, or approximated) on a strip of your terminal background. Picking
// one switches the prompt on (TerminalLookService.enablePrompt).
Item {
    id: root

    readonly property string current: Config.terminal ? Config.terminal.prompt : ""
    // Mark the configured preset only while the prompt is on (onboarding:
    // nothing tells there that a marked card is not in use yet, and a card
    // that looks picked is never clicked). Settings marks it either way and
    // says the prompt is off.
    property bool markOnlyWhenOn: false
    readonly property bool marking: !root.markOnlyWhenOn || !!(Config.terminal && Config.terminal.enabled)
    readonly property string engine: TerminalLookService.engine
    readonly property int columns: width < 520 ? 1 : (width < 860 ? 2 : 3)

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Space.m

        Repeater {
            model: TerminalLookService.presets

            delegate: ChoiceCard {
                id: card
                required property var modelData
                readonly property var result: TerminalLookService.previews[TermModel.previewKey(root.engine, modelData.id)]
                readonly property var promptLines: card.result && card.result.left ? card.result.left : []
                readonly property var rightSpans: card.result ? (card.result.right || []) : []

                objectName: "promptCard:" + modelData.id
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: 64
                selected: root.marking && root.current === modelData.id
                title: modelData.name
                subtitle: I18n.t(modelData.description)
                onClicked: TerminalLookService.enablePrompt(modelData.id)

                Component.onCompleted: TerminalLookService.ensure(modelData.id, root.engine)
                Connections {
                    target: root
                    function onEngineChanged() {
                        TerminalLookService.ensure(card.modelData.id, root.engine);
                    }
                }

                // A strip of the terminal background (graphics, not a box).
                Mark {
                    anchors.fill: parent
                    radius: Look.radius("control", height)
                    color: Colors.background
                    border.width: Space.hairline
                    border.color: Qt.alpha(Colors.outlineVariant, 0.5)

                    Item {
                        id: strip
                        anchors.fill: parent
                        anchors.leftMargin: Space.s
                        anchors.rightMargin: Space.s
                        clip: true

                        // Natural size, scaled down to fit the strip; long
                        // prompts stop shrinking at minScale and fade out
                        // (the right prompt goes first).
                        Item {
                            id: prompt
                            readonly property real minScale: 0.8
                            readonly property real rightWidth: rightLine.contentWidth + 2 * rightLine.lineHeight
                            readonly property bool showRight: card.rightSpans.length > 0 && strip.width / Math.max(1, leftCol.width + rightWidth) >= minScale
                            readonly property real natural: Math.max(1, leftCol.width + (showRight ? rightWidth : 0))
                            readonly property bool overflows: natural * scale > strip.width + 0.5
                            width: Math.max(natural, strip.width / scale)
                            height: leftCol.height
                            scale: Math.max(minScale, Math.min(1, strip.width / natural))
                            transformOrigin: Item.Left
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: card.result ? 1 : 0
                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Motion.enter.duration
                                }
                            }

                            Column {
                                id: leftCol
                                Repeater {
                                    model: card.promptLines
                                    delegate: PromptLine {
                                        required property var modelData
                                        spans: modelData
                                        fontFamily: TerminalLookService.fontFamily
                                        pixelSize: 13
                                        foreground: Colors.overSurface
                                    }
                                }
                            }
                            PromptLine {
                                id: rightLine
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                visible: prompt.showRight
                                spans: card.rightSpans
                                fontFamily: TerminalLookService.fontFamily
                                pixelSize: 13
                                foreground: Colors.overSurface
                            }
                        }

                        Mark {
                            anchors.right: parent.right
                            radius: 0
                            width: Space.controlS
                            height: parent.height
                            visible: prompt.overflows && card.result !== undefined
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: Qt.alpha(Colors.background, 0)
                                }
                                GradientStop {
                                    position: 1
                                    color: Colors.background
                                }
                            }
                        }

                        // Placeholder bars while the engine renders.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Space.xs
                            visible: !card.result
                            Repeater {
                                model: [46, 78, 30]
                                delegate: Mark {
                                    required property int modelData
                                    width: modelData
                                    height: Type.size("body")
                                    color: Type.placeholder
                                }
                            }
                        }
                    }

                    Mark {
                        objectName: "nerdFreeBadge"
                        visible: !card.modelData.nerdFont
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Space.xs
                        width: badgeText.implicitWidth + Space.m
                        height: badgeText.implicitHeight + Space.xs
                        color: Qt.alpha(Colors.tertiary, 0.18)
                        KitText {
                            id: badgeText
                            anchors.centerIn: parent
                            role: "label"
                            text: I18n.t("prefs.term.look.nerd_free")
                            color: Colors.tertiary
                        }
                    }
                }
            }
        }
    }
}
