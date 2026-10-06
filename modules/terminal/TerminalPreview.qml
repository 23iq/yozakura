pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.globals
import qs.modules.settings.previews
import "TermModel.js" as TermModel
import "../settings/Ui.js" as Ui

// A fake kitty window over your wallpaper: the terminal background at the
// kitty opacity over the blurred wallpaper, your padding, font and cursor,
// and the prompt (`preview`, a `term.preview` result) running `ls` and
// `git status -s` in the fixture repo the backend renders it in.
Item {
    id: root

    // {left: [[span]], right: [span], exact, engine, reason} or undefined
    property var preview
    property string fontFamily: "monospace"
    property real pixelSize: 15
    property real padding: 12
    property string cursorShape: "beam"
    property bool cursorBlink: true
    property bool greeting: false
    property real backgroundOpacity: 1
    property bool animate: true

    readonly property var promptLines: root.preview && root.preview.left && root.preview.left.length > 0 ? root.preview.left : [[]]
    readonly property var rightSpans: root.preview ? (root.preview.right || []) : []
    readonly property color fg: Colors.overSurface
    readonly property real cell: Math.max(1, root.cellWidth(cellMetrics.font))
    readonly property real pad: Math.round(root.padding * root.fit)
    readonly property real lineHeight: Math.ceil(cellMetrics.height)
    readonly property int cols: Math.floor((termArea.width - 2 * root.pad) / root.cell)
    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: {
        const m = root.manager;
        if (!m || !m.currentWallpaper)
            return "";
        const p = m.getColorSource ? m.getColorSource(m.currentWallpaper) : m.currentWallpaper;
        return p ? "file://" + p : "";
    }

    // Sample session: [{cmd} | {out: [span]}] after each prompt.
    readonly property var session: [
        {
            "cmd": "ls",
            "out": [[
                    {
                        "text": "assets  backend  modules",
                        "fg": Colors.blue,
                        "bold": true
                    },
                    {
                        "text": "  go.mod  README.md  shell.qml"
                    }
                ]]
        },
        {
            "cmd": "git status -s",
            "out": [[
                    {
                        "text": "M ",
                        "fg": Colors.green
                    },
                    {
                        "text": " modules/shell.qml"
                    }
                ], [
                    {
                        "text": " M",
                        "fg": Colors.red
                    },
                    {
                        "text": " README.md"
                    }
                ], [
                    {
                        "text": "??",
                        "fg": Colors.red
                    },
                    {
                        "text": " notes.md"
                    }
                ]]
        },
        {
            "cmd": "",
            "out": []
        }
    ]
    readonly property var fetchLines: [[
            {
                "text": " \uf303  ",
                "fg": Colors.blue,
                "bold": true
            },
            {
                "text": "you",
                "fg": Colors.primary,
                "bold": true
            },
            {
                "text": "@"
            },
            {
                "text": Brand.appId,
                "fg": Colors.primary,
                "bold": true
            }
        ], [
            {
                "text": "  OS     ",
                "fg": Colors.tertiary
            },
            {
                "text": "Arch Linux"
            }
        ], [
            {
                "text": "  Shell  ",
                "fg": Colors.tertiary
            },
            {
                "text": "fish"
            }
        ], [
            {
                "text": "  Term   ",
                "fg": Colors.tertiary
            },
            {
                "text": "kitty"
            }
        ], []]

    // `font` only makes the binding follow font changes.
    function cellWidth(font) {
        return cellMetrics.advanceWidth("M");
    }

    // The window shows at least `minColumns` (a usual terminal; prompts are
    // made for it): on a narrow page the font and padding shrink to fit,
    // like a smaller kitty font would (text stays crisp, no scaling). A
    // monospace cell is about 0.6 em wide.
    readonly property int minColumns: 90
    readonly property real margin: Math.round(Math.min(32, root.width * 0.05))
    readonly property real fit: Math.min(1, (root.width - 2 * root.margin) / Math.max(1, root.minColumns * root.pixelSize * 0.6 + 2 * root.padding))
    readonly property real shownPixelSize: Math.max(9, Math.floor(root.pixelSize * root.fit))

    implicitHeight: windowFrame.y + windowFrame.height + 26

    FontMetrics {
        id: baseMetrics
        font.family: root.fontFamily
        font.pixelSize: root.shownPixelSize
    }
    FontMetrics {
        id: cellMetrics
        font.family: root.fontFamily
        font.pixelSize: root.shownPixelSize
    }

    ClippingRectangle {
        id: stage
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Colors.surfaceContainerLowest

        ScreenBackdrop {
            anchors.fill: parent
            radius: 0
            visible: wall.status !== Image.Ready
        }
        Image {
            id: wall
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 1200
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            color: Ui.alpha(Colors.background, 0.18)
        }

        RectangularShadow {
            x: windowFrame.x
            y: windowFrame.y
            width: windowFrame.width
            height: windowFrame.height
            radius: 12
            blur: 28
            offset.y: 8
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        // The compositor blur under the translucent terminal.
        ClippingRectangle {
            x: windowFrame.x
            y: windowFrame.y
            width: windowFrame.width
            height: windowFrame.height
            radius: 12
            color: "transparent"
            visible: wall.status === Image.Ready

            MultiEffect {
                x: -parent.x
                y: -parent.y
                width: stage.width
                height: stage.height
                source: wall
                blurEnabled: true
                blur: 0.8
                blurMax: 48
            }
        }
    }

    Item {
        id: windowFrame
        objectName: "kittyWindow"
        x: root.margin
        y: 26
        width: root.width - 2 * root.margin
        height: titleBar.height + termArea.height

        ClippingRectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.7)

            Rectangle {
                anchors.fill: parent
                color: Colors.background
                opacity: root.backgroundOpacity
            }

            Item {
                id: titleBar
                width: parent.width
                height: 30

                Rectangle {
                    anchors.fill: parent
                    color: Ui.alpha(Colors.surfaceContainerHigh, 0.55)
                }
                Row {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Repeater {
                        model: [Colors.error, Colors.tertiary, Colors.green]
                        delegate: Rectangle {
                            required property color modelData
                            width: 11
                            height: 11
                            radius: 5.5
                            color: Ui.alpha(modelData, 0.85)
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "fish  ~/" + Brand.appId
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(10, root.shownPixelSize - 3)
                    color: Ui.alpha(Colors.overSurfaceVariant, 0.9)
                }
            }

            Item {
                id: termArea
                y: titleBar.height
                width: parent.width
                height: lines.implicitHeight + 2 * root.pad

                Column {
                    id: lines
                    x: root.pad
                    y: root.pad
                    width: parent.width - 2 * root.pad
                    clip: true

                    Repeater {
                        model: root.greeting ? root.fetchLines : []
                        delegate: PromptLine {
                            required property var modelData
                            spans: modelData
                            fontFamily: root.fontFamily
                            pixelSize: root.shownPixelSize
                            lineHeight: root.lineHeight
                            foreground: root.fg
                        }
                    }

                    Repeater {
                        model: root.session
                        delegate: Column {
                            id: step
                            required property var modelData
                            required property int index
                            readonly property bool last: index === root.session.length - 1
                            width: lines.width

                            // Prompt lines above the input line
                            Repeater {
                                model: root.promptLines.slice(0, root.promptLines.length - 1)
                                delegate: PromptLine {
                                    required property var modelData
                                    spans: modelData
                                    fontFamily: root.fontFamily
                                    pixelSize: root.shownPixelSize
                                    lineHeight: root.lineHeight
                                    foreground: root.fg
                                }
                            }

                            // Input line: prompt + command (+ cursor), right prompt
                            Item {
                                width: lines.width
                                height: root.lineHeight

                                PromptLine {
                                    id: inputLine
                                    objectName: step.last ? "inputLine" : ""
                                    spans: root.promptLines[root.promptLines.length - 1].concat([
                                        {
                                            "text": step.modelData.cmd
                                        }
                                    ])
                                    fontFamily: root.fontFamily
                                    pixelSize: root.shownPixelSize
                                    lineHeight: root.lineHeight
                                    foreground: root.fg
                                }
                                PromptLine {
                                    objectName: step.last ? "rightPrompt" : ""
                                    anchors.right: parent.right
                                    visible: root.rightSpans.length > 0 && TermModel.alignRight(inputLine.spans, root.rightSpans, root.cols) > 0
                                    spans: root.rightSpans
                                    fontFamily: root.fontFamily
                                    pixelSize: root.shownPixelSize
                                    lineHeight: root.lineHeight
                                    foreground: root.fg
                                }
                                Rectangle {
                                    id: cursor
                                    objectName: step.last ? "cursor" : ""
                                    visible: step.last
                                    x: inputLine.contentWidth
                                    y: root.cursorShape === "underline" ? root.lineHeight - height : 0
                                    width: root.cursorShape === "block" ? root.cell : (root.cursorShape === "beam" ? Math.max(2, Math.round(root.shownPixelSize / 8)) : root.cell)
                                    height: root.cursorShape === "underline" ? Math.max(2, Math.round(root.shownPixelSize / 8)) : root.lineHeight
                                    color: root.fg
                                    opacity: blink.on ? 1 : 0
                                }
                            }

                            Repeater {
                                model: step.modelData.out
                                delegate: PromptLine {
                                    required property var modelData
                                    spans: modelData
                                    fontFamily: root.fontFamily
                                    pixelSize: root.shownPixelSize
                                    lineHeight: root.lineHeight
                                    foreground: root.fg
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: blink
        property bool on: true
        interval: 530
        repeat: true
        running: root.cursorBlink && root.animate && root.visible
        onTriggered: on = !on
        onRunningChanged: on = true
    }
}
