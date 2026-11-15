pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import "../HomeStatus.js" as HomeStatus

// Home tile scene of Panels: a small screen with the launcher where it
// opens now (HomeStatus.launcherHost: grown out of the island, a spotlight
// card in the middle, a sheet from the bottom), its search line and the
// first apps, the picked one lit.
Item {
    id: scene

    required property Card tile

    readonly property bool island: SettingsStore.get("notch.enabled") !== false
    readonly property string host: HomeStatus.launcherHost({
        "get": k => SettingsStore.get(k)
    })
    readonly property real sw: screen.screenWidth
    readonly property real sh: screen.screenHeight
    // the launcher's box in the screen, by host
    readonly property rect box: scene.host === "notch" ? Qt.rect(scene.sw * 0.24, -panel.radius, scene.sw * 0.52, scene.sh * 0.66 + panel.radius) : scene.host === "sheet" ? Qt.rect(scene.sw * 0.12, scene.sh * 0.34, scene.sw * 0.76, scene.sh * 0.66 + panel.radius) : Qt.rect(scene.sw * 0.22, scene.sh * 0.17, scene.sw * 0.56, scene.sh * 0.66)
    readonly property var swatches: [Colors.primary, Colors.tertiary, Colors.secondary]

    SceneScreen {
        id: screen
        anchors.fill: parent

        // the island (the launcher grows out of it when it is the host)
        Mark {
            visible: scene.island && scene.host !== "notch"
            x: Math.round((scene.sw - width) / 2)
            y: Space.xs
            width: Math.round(scene.sw * 0.2)
            height: Math.max(Space.s, Math.round(scene.sh * 0.07))
            color: Colors.background
            border.width: Space.hairline
            border.color: Type.hairline
        }

        Mark {
            id: panel
            x: Math.round(scene.box.x)
            y: Math.round(scene.box.y)
            width: Math.round(scene.box.width)
            height: Math.round(scene.box.height)
            radius: Look.radius("small", scene.sh * 0.6)
            color: Colors.background
            border.width: Space.hairline
            border.color: Type.hairline

            Column {
                id: list
                x: Space.s
                // under the part of the box hidden above the screen
                y: Math.max(0, -panel.y) + Space.s
                width: panel.width - Space.s * 2
                spacing: Space.xs
                readonly property real rowH: Math.max(Space.s, Math.min(Space.l, (scene.sh * 0.6 - Space.s * 2) / 5))

                // the search line: a lens and the caret
                Mark {
                    width: parent.width
                    height: list.rowH
                    radius: Look.radius("control", height)
                    color: Type.track
                    Icon {
                        x: Space.xs
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.magnifyingGlass
                        size: Math.max(Space.s, Math.round(parent.height * 0.6))
                        tone: "muted"
                    }
                }
                Repeater {
                    model: 3
                    delegate: Mark {
                        id: row
                        required property int index
                        width: list.width
                        height: list.rowH
                        radius: Look.radius("control", height)
                        color: row.index === 0 ? Look.tonal(Type.accent) : "transparent"
                        Mark {
                            x: Space.xs
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(row.height * 0.62)
                            height: width
                            radius: Look.radius("small", height)
                            color: scene.swatches[row.index]
                        }
                        Mark {
                            x: Space.xs * 2 + Math.round(row.height * 0.62)
                            anchors.verticalCenter: parent.verticalCenter
                            width: (row.width - x) * (row.index === 0 ? 0.6 : 0.45)
                            height: Math.max(Space.hairline * 2, Math.round(row.height * 0.24))
                            color: row.index === 0 ? Type.accent : Type.track
                        }
                    }
                }
            }
        }
    }
}
