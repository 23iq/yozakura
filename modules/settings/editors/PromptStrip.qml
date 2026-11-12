pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.terminal
import qs.modules.components.kit
import qs.modules.settings.controls
import "../../terminal/TermModel.js" as TermModel

// The fish prompts as a strip of pictures (a card of the page row): each
// preset drawn as it renders (TerminalLookService previews, the engine in
// use) on the terminal background, its name inside; the one in use ringed
// while the prompt is on. A click uses it (TerminalLookService.enablePrompt:
// it also turns the prompt on).
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property string current: Config.terminal ? Config.terminal.prompt : ""
    readonly property bool on: !!(Config.terminal && Config.terminal.enabled)
    readonly property string engine: TerminalLookService.engine
    readonly property var presets: TerminalLookService.presets || []
    readonly property real cardH: root.fillHeight > 0 ? root.fillHeight - Space.s * 2 : Space.px(110)
    readonly property real cardW: Math.round(root.cardH * 1.7)

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : root.cardH + Space.s * 2

    // the prompt in use in view (centred when it can be)
    function reveal() {
        const i = root.presets.findIndex(p => p.id === root.current);
        if (i < 0 || flick.width <= 0)
            return;
        const x = Space.m + i * (root.cardW + Space.m) - (flick.width - root.cardW) / 2;
        flick.contentX = Math.max(0, Math.min(x, flick.contentWidth - flick.width));
    }
    onCurrentChanged: Qt.callLater(root.reveal)
    onPresetsChanged: Qt.callLater(root.reveal)
    onWidthChanged: Qt.callLater(root.reveal)

    Flickable {
        id: flick
        objectName: "promptStrip"
        anchors.fill: parent
        contentWidth: row.width + Space.m * 2
        interactive: contentWidth > width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        onContentWidthChanged: Qt.callLater(root.reveal)

        Row {
            id: row
            x: Space.m
            y: Space.s
            spacing: Space.m
            Repeater {
                model: root.presets
                delegate: ChoiceCard {
                    id: card
                    required property var modelData
                    readonly property var result: TerminalLookService.previews[TermModel.previewKey(root.engine, modelData.id)]
                    objectName: "promptCard:" + modelData.id
                    width: root.cardW
                    previewHeight: root.cardH
                    inset: true
                    selected: root.on && root.current === modelData.id
                    title: modelData.name
                    onClicked: TerminalLookService.enablePrompt(modelData.id)
                    Component.onCompleted: TerminalLookService.ensure(modelData.id, root.engine)

                    Mark {
                        anchors.fill: parent
                        radius: 0
                        color: Colors.background
                    }
                    // the prompt, as large as the picture allows, over the title
                    Item {
                        id: area
                        x: Space.s
                        width: parent.width - Space.s * 2
                        height: parent.height * 0.62
                        clip: true
                        Column {
                            id: lines
                            anchors.verticalCenter: parent.verticalCenter
                            scale: Math.min(1, area.width / Math.max(1, lines.implicitWidth))
                            transformOrigin: Item.Left
                            Repeater {
                                model: card.result && card.result.left ? card.result.left : []
                                delegate: PromptLine {
                                    required property var modelData
                                    spans: modelData
                                    fontFamily: TerminalLookService.fontFamily
                                    pixelSize: Type.size("body")
                                    foreground: Colors.overSurface
                                }
                            }
                        }
                    }
                    // while the engine renders it
                    Row {
                        x: Space.s
                        y: Space.m
                        spacing: Space.xs
                        visible: !card.result
                        Repeater {
                            model: [0.3, 0.42, 0.18]
                            delegate: Mark {
                                required property real modelData
                                width: card.width * modelData
                                height: Type.size("caption")
                                color: Type.placeholder
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
