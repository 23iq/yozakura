pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store
import "../../shell/hosts/HostResolve.js" as HostResolve
import "../../widgets/launcher/Providers.js" as Providers
import "SurfacePlace.js" as SurfacePlace

// Stage of Launcher: your screen with the launcher open where it opens
// (HostResolve: grown from the island, a spotlight in the middle or a side
// sheet), the windows faded back. It is live: a search for "fi" answered by
// the providers that are on, in their order (one sample result each), in
// the result style (list, cards or a grid), with or without icons and the
// preview pane, and the tab providers' prefixes at the bottom. A click on
// it opens Where things open on the launcher.
Stage {
    id: stage
    objectName: "launcherStage"

    readonly property var order: SettingsStore.get("prefix.launcher.order") || []
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property string style: String(SettingsStore.get("layout.launcher.resultStyle") || "list")
    readonly property bool icons: SettingsStore.get("layout.launcher.icons") !== false
    readonly property bool preview: SettingsStore.get("layout.launcher.preview") === true
    readonly property string host: HostResolve.resolve({
        "launcher": {
            "host": SettingsStore.get("layout.launcher.host")
        }
    }, "launcher", {
        "notchEnabled": SettingsStore.get("notch.enabled") !== false
    })
    readonly property var place: SurfacePlace.rect(stage.host, mini.freeRect, mini.islandRect, {
        "islandEdge": mini.islandEdge,
        "sheetSide": SettingsStore.get("layout.sheet.side") === "left" ? "left" : "right"
    })
    readonly property bool grid: stage.style === "grid"
    readonly property var results: SurfacePlace.results(Providers.active(stage.order, stage.disabled), stage.grid ? 8 : (stage.style === "cards" ? 4 : 6))
    readonly property var tabs: Providers.TAB_IDS.filter(id => Providers.isEnabled(id, stage.disabled))

    stageHeight: Space.px(300)

    ScreenMini {
        id: mini
        anchors.fill: parent
        barOpacity: stage.barOpacity
        cornerRadius: stage.radius
        windowsOpacity: 0.3

        StyledRect {
            id: launcher
            objectName: "launcherMini"
            readonly property real u: mini.unit
            readonly property real pad: Math.round(u * 0.5)
            x: stage.place.x
            y: stage.place.y
            width: stage.place.w
            height: stage.place.h
            variant: "popup"
            enableShadow: true
            radius: Look.radius("box", Space.controlL)
            Behavior on x {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
            Behavior on width {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }

            // the search field
            Mark {
                id: field
                x: launcher.pad
                y: launcher.pad
                width: launcher.width - launcher.pad * 2
                height: Math.round(launcher.u * 1.5)
                radius: Look.radius("control", height)
                color: Look.raisedFill(false)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: launcher.pad
                    spacing: Space.s
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.magnifyingGlass
                        role: "secondary"
                        tone: "muted"
                    }
                    KitText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "secondary"
                        color: Type.text
                        text: "fi"
                    }
                    Mark {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Space.hairline * 2
                        height: Math.round(launcher.u * 0.7)
                        radius: 0
                        color: Type.accent
                    }
                }
            }

            // results (and the preview pane beside them)
            Item {
                id: body
                x: launcher.pad
                y: field.y + field.height + launcher.pad
                width: launcher.width - launcher.pad * 2
                height: launcher.height - y - launcher.pad - (tabRow.visible ? tabRow.height + launcher.pad : 0)
                clip: true
                readonly property real listW: stage.preview ? Math.round(width * 0.6) : width

                // list / cards: one row per result
                Column {
                    visible: !stage.grid
                    width: body.listW
                    spacing: Math.round(launcher.u * 0.15)
                    Repeater {
                        model: stage.grid ? [] : stage.results
                        delegate: Mark {
                            id: rowMark
                            required property var modelData
                            required property int index
                            readonly property bool cards: stage.style === "cards"
                            width: body.listW
                            height: Math.round(launcher.u * (rowMark.cards ? 1.9 : 1.15))
                            radius: Look.radius("small", height)
                            color: rowMark.index === 0 ? Qt.alpha(Type.accent, 0.16) : (rowMark.cards ? Look.raisedFill(false) : "transparent")
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round(launcher.u * 0.35)
                                spacing: Math.round(launcher.u * 0.35)
                                Icon {
                                    visible: stage.icons
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: Icons[rowMark.modelData.icon] ?? ""
                                    role: rowMark.cards ? "body" : "secondary"
                                    tone: rowMark.index === 0 ? "accent" : "secondary"
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    KitText {
                                        role: "secondary"
                                        color: Type.text
                                        text: rowMark.modelData.title
                                    }
                                    KitText {
                                        visible: rowMark.cards
                                        role: "caption"
                                        text: I18n.t(rowMark.modelData.detail)
                                    }
                                }
                            }
                        }
                    }
                }

                // grid: tiles of icons with a short name
                Grid {
                    visible: stage.grid
                    width: body.listW
                    columns: 4
                    spacing: Math.round(launcher.u * 0.2)
                    Repeater {
                        model: stage.grid ? stage.results : []
                        delegate: Mark {
                            id: tile
                            required property var modelData
                            required property int index
                            width: (body.listW - launcher.u * 0.6) / 4
                            height: width * 0.86
                            radius: Look.radius("small", height)
                            color: tile.index === 0 ? Qt.alpha(Type.accent, 0.16) : Look.raisedFill(false)
                            Icon {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -parent.height * 0.1
                                icon: Icons[tile.modelData.icon] ?? ""
                                size: Math.round(parent.height * 0.36)
                                tone: tile.index === 0 ? "accent" : "secondary"
                            }
                            KitText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Math.round(parent.height * 0.06)
                                width: parent.width - Space.xs * 2
                                horizontalAlignment: Text.AlignHCenter
                                role: "caption"
                                color: Type.text
                                text: tile.modelData.title
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // the preview pane: the first result, large
                Mark {
                    id: pane
                    objectName: "launcherPreview"
                    visible: stage.preview
                    x: body.listW + launcher.pad
                    width: body.width - x
                    height: body.height
                    radius: Look.radius("small", Space.controlL)
                    color: Look.raisedFill(false)
                    Icon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -parent.height * 0.12
                        icon: stage.results.length > 0 ? (Icons[stage.results[0].icon] ?? "") : ""
                        size: Math.round(Math.min(parent.width, parent.height) * 0.3)
                        tone: "accent"
                    }
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.66
                        spacing: Math.round(launcher.u * 0.2)
                        Repeater {
                            model: [0.6, 0.4]
                            delegate: Mark {
                                required property real modelData
                                width: pane.width * modelData
                                height: Math.max(2, Math.round(launcher.u * 0.18))
                                color: Qt.alpha(Type.text, 0.3)
                            }
                        }
                    }
                    StageSpot {
                        keys: ["layout.launcher.preview"]
                        cornerRadius: pane.radius
                    }
                }

                StageSpot {
                    width: body.listW
                    anchors.fill: undefined
                    height: body.height
                    keys: ["prefix.launcher.disabled", "prefix.launcher.order", "layout.launcher.resultStyle", "layout.launcher.icons"]
                }
            }

            // tab providers: their prefixes
            Row {
                id: tabRow
                visible: stage.tabs.length > 0 && launcher.height > launcher.u * 8
                x: launcher.pad
                y: launcher.height - height - launcher.pad
                spacing: Space.s
                Repeater {
                    model: stage.tabs
                    delegate: KeyHint {
                        required property string modelData
                        icon: Icons[(Providers.byId(modelData) || {}).icon] ?? ""
                        text: String(SettingsStore.get("prefix." + modelData) || "")
                    }
                }
                StageSpot {
                    keys: ["prefix.clipboard", "prefix.emoji", "prefix.tmux", "prefix.notes"]
                }
            }

            MouseArea {
                objectName: "launcherMiniArea"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.navigate("layout", "", "layout.launcher.host")
            }
        }
    }
}
