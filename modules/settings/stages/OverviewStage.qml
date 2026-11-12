pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Overview: your screen with the workspace overview open over the
// dimmed desktop, drawn from the live config: the workspaces as previews of
// your wallpaper (the first one ringed, a few windows on each) in its style
// (a grid of rows x columns, one strip, or a scrolling tape), each preview
// the configured share of the screen apart by the configured spacing. The
// + / - buttons beside the grid add or remove a column (and a row in the
// grid), the keyboard path being the Grid card's sliders.
Stage {
    id: stage
    objectName: "overviewStage"

    readonly property string style: String(SettingsStore.get("overview.style") || "grid")
    readonly property bool grid: stage.style === "grid"
    readonly property int rows: stage.grid ? Math.max(1, Number(SettingsStore.get("overview.rows") || 2)) : 1
    readonly property int columns: Math.max(1, Number(SettingsStore.get("overview.columns") || 5))
    readonly property real scaleSetting: Number(SettingsStore.get("overview.scale") || 0.15)
    readonly property real spacingSetting: Number(SettingsStore.get("overview.workspaceSpacing") ?? 8)

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        showWindows: false

        Mark {
            anchors.fill: parent
            radius: 0
            color: Qt.alpha(Colors.shadow, 0.5)
        }

        Item {
            id: board
            objectName: "overviewBoard"
            readonly property real gap: Math.max(Space.xs, stage.spacingSetting * mini.width / 1920)
            // the previews at the configured share of the screen, shrunk only
            // when they would not fit the free area (the scrolling tape runs
            // off the screen on purpose)
            readonly property real fit: stage.style === "scroll" ? 1 : Math.min(1, (mini.freeRect.w * 0.86 - board.gap * (stage.columns - 1)) / (mini.width * stage.scaleSetting * stage.columns), (mini.freeRect.h * 0.8 - board.gap * (stage.rows - 1)) / (mini.height * stage.scaleSetting * stage.rows))
            readonly property real tileW: mini.width * stage.scaleSetting * board.fit * (stage.style === "scroll" ? 1.8 : 1)
            readonly property real tileH: board.tileW * mini.height / Math.max(1, mini.width)
            width: stage.columns * board.tileW + (stage.columns - 1) * board.gap
            height: stage.rows * board.tileH + (stage.rows - 1) * board.gap
            x: stage.style === "scroll" ? mini.freeRect.x + mini.unit : mini.freeRect.x + (mini.freeRect.w - width) / 2
            y: mini.freeRect.y + (mini.freeRect.h - height) / 2

            Grid {
                columns: stage.columns
                spacing: board.gap
                Repeater {
                    model: stage.rows * stage.columns
                    delegate: Item {
                        id: tile
                        required property int index
                        objectName: "overviewWorkspace:" + (index + 1)
                        width: board.tileW
                        height: board.tileH

                        Art {
                            anchors.fill: parent
                            source: stage.wallpaper
                            radius: Look.radius("small", height)
                        }
                        // a few windows on the busier workspaces
                        Repeater {
                            model: tile.index % 3 === 2 ? 0 : (tile.index % 3 === 0 ? 2 : 1)
                            delegate: Mark {
                                required property int index
                                x: tile.width * (0.08 + index * 0.46)
                                y: tile.height * 0.18
                                width: tile.width * (index === 0 && tile.index % 3 === 1 ? 0.84 : 0.4)
                                height: tile.height * 0.66
                                radius: Look.radius("small", height) / 2
                                color: Qt.alpha(Colors.surfaceContainer, 0.85)
                                border.width: Space.hairline
                                border.color: Qt.alpha(Colors.outlineVariant, 0.7)
                            }
                        }
                        KitText {
                            x: Space.xs
                            y: Space.xs / 2
                            visible: tile.height > Space.px(28)
                            role: "caption"
                            color: Type.text
                            text: tile.index + 1
                        }
                        Mark {
                            anchors.fill: parent
                            anchors.margins: tile.index === 0 ? -Space.hairline * 2 : 0
                            radius: Look.radius("small", height)
                            color: "transparent"
                            border.width: tile.index === 0 ? Space.stroke - 1 : Space.hairline
                            border.color: tile.index === 0 ? Type.accent : Type.hairline
                        }
                    }
                }
            }
            StageSpot {
                keys: ["overview.style", "overview.rows", "overview.columns", "overview.scale", "overview.workspaceSpacing"]
            }
        }

        // add / remove a column (right of the grid) and a row (under it)
        Column {
            objectName: "overviewColumnsButtons"
            visible: stage.style !== "scroll"
            x: board.x + board.width + Space.s
            y: board.y + (board.height - height) / 2
            spacing: Space.xs
            Stepper {
                key: "overview.columns"
                delta: 1
                value: stage.columns
                name: "overviewMore:columns"
            }
            Stepper {
                key: "overview.columns"
                delta: -1
                value: stage.columns
                name: "overviewLess:columns"
            }
        }
        Row {
            objectName: "overviewRowsButtons"
            visible: stage.grid
            x: board.x + (board.width - width) / 2
            y: board.y + board.height + Space.s
            spacing: Space.xs
            Stepper {
                key: "overview.rows"
                delta: 1
                value: stage.rows
                name: "overviewMore:rows"
            }
            Stepper {
                key: "overview.rows"
                delta: -1
                value: stage.rows
                name: "overviewLess:rows"
            }
        }
    }

    // one + / - step of a count (1..10)
    component Stepper: IconButton {
        id: stepper
        property string key: ""
        property int delta: 1
        property int value: 1
        property string name: ""
        objectName: stepper.name
        size: "xs"
        enabled: stepper.value + stepper.delta >= 1 && stepper.value + stepper.delta <= 10
        icon: stepper.delta > 0 ? Icons.plus : Icons.minus
        onClicked: SettingsStore.set(stepper.key, stepper.value + stepper.delta)
    }
}
