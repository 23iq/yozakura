pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.config
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components
import qs.modules.bar.workspaces

// Miniature workspaces (dock): the wallpaper with each window drawn at its
// place and its app icon, the active one outlined. Click switches.
// moduleOptions.workspacePreviews.count; geometry from CompositorData, the
// same window data the overview uses.
BarModuleBase {
    id: root

    moduleKey: "workspacePreviews"

    readonly property var monitor: bar ? YozdService.monitorFor(bar.screen) : null
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property int count: Math.max(1, Math.min(10, options.count !== undefined ? options.count : 4))
    readonly property int first: Math.floor((activeId - 1) / count) * count + 1
    readonly property real screenW: bar && bar.screen && bar.screen.width ? bar.screen.width : 1920
    readonly property real screenH: bar && bar.screen && bar.screen.height ? bar.screen.height : 1080
    readonly property real monX: monitor && monitor.x !== undefined ? monitor.x : 0
    readonly property real monY: monitor && monitor.y !== undefined ? monitor.y : 0
    readonly property real thumbH: Math.round(moduleSize * (vertical ? 0.5 : 0.78))
    readonly property real thumbW: Math.round(thumbH * screenW / screenH)
    readonly property string wallpaper: GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.currentWallpaper ? GlobalStates.wallpaperManager.currentWallpaper : ""

    contentLength: vertical ? count * (thumbH + 6) + 6 : count * (thumbW + 8) + 4

    Grid {
        anchors.centerIn: parent
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        spacing: root.vertical ? 6 : 8

        Repeater {
            model: root.count
            delegate: Item {
                id: thumb
                required property int index
                readonly property int ws: root.first + index
                readonly property bool active: ws === root.activeId
                readonly property var windows: CompositorData.workspaceWindowsMap[ws] || []
                width: root.vertical ? Math.min(root.moduleSize - 8, root.thumbW) : root.thumbW
                height: root.vertical ? Math.round(width * root.screenH / root.screenW) : root.thumbH
                scale: mouse.containsMouse ? 1.06 : 1
                Behavior on scale {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                        easing.type: Motion.morph.easing
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Math.min(Styling.radius(-6), 6)
                    color: Colors.surfaceContainerHigh

                    Image {
                        anchors.fill: parent
                        visible: root.wallpaper !== ""
                        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                        sourceSize.width: Math.round(root.thumbW * 2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: thumb.active ? 1 : 0.75
                    }

                    Repeater {
                        model: thumb.windows
                        delegate: Rectangle {
                            id: win
                            required property var modelData
                            readonly property real sx: thumb.width / root.screenW
                            readonly property real sy: thumb.height / root.screenH
                            x: Math.max(0, ((modelData.at ? modelData.at[0] : 0) - root.monX) * sx)
                            y: Math.max(0, ((modelData.at ? modelData.at[1] : 0) - root.monY) * sy)
                            width: Math.max(4, (modelData.size ? modelData.size[0] : 0) * sx)
                            height: Math.max(4, (modelData.size ? modelData.size[1] : 0) * sy)
                            radius: 2
                            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.88)
                            border.width: 1
                            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)

                            Image {
                                anchors.centerIn: parent
                                readonly property real side: Math.min(parent.width, parent.height) * 0.55
                                width: side
                                height: side
                                visible: side >= 6
                                source: "image://icon/" + AppSearch.guessIcon(win.modelData["class"] || "")
                                sourceSize: Qt.size(32, 32)
                                mipmap: true
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: Math.min(Styling.radius(-6), 6) + 2
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.primary
                    visible: thumb.active
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    text: thumb.ws
                    font.family: Config.theme.font
                    font.pixelSize: Math.max(8, Math.round(thumb.height * 0.26))
                    font.weight: Font.Bold
                    color: "white"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: YozdService.dispatch(`workspace ${thumb.ws}`)
                }
            }
        }
    }
}
