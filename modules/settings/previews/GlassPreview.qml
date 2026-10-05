import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.controls
import qs.config
import "../Ui.js" as Ui

// Live glass over a slice of the real wallpaper: a popup and a notch pill
// drawn with the real StyledRect (glass opacity, tint, highlight) over the
// wallpaper blurred like the compositor would (Glass.compositor), plus the
// worst-case text contrast the legibility clamp guarantees.
PreviewStage {
    id: root

    property var entry
    stageHeight: 210

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: manager && manager.currentWallpaper ? (manager.getColorSource ? manager.getColorSource(manager.currentWallpaper) : manager.currentWallpaper) : ""
    readonly property var blurCfg: Glass.compositor.blur
    // Hyprland's kawase blur grows with size x passes; MultiEffect's 0..1.
    readonly property real blurAmount: blurCfg.enabled ? Math.min(1, blurCfg.size * Math.sqrt(blurCfg.passes) / 28) : 0
    readonly property real popupOpacity: Glass.variantOpacity("popup", Config.theme.srPopup.opacity, "popups")
    readonly property real contrast: Glass.worstContrast("popup", popupOpacity)

    Item {
        id: scene
        anchors.fill: parent

        ScreenBackdrop {
            id: fallback
            anchors.fill: parent
            radius: 0
            visible: wall.status !== Image.Ready
        }

        Image {
            id: wall
            anchors.fill: parent
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 960
            visible: status === Image.Ready
        }

        GlassPanel {
            id: notchPill
            backdrop: wall.status === Image.Ready ? wall : fallback
            blurCfg: root.blurCfg
            blurAmount: root.blurAmount
            variant: "bg"
            surface: "notch"
            width: Math.min(220, scene.width * 0.36)
            height: 30
            x: (scene.width - width) / 2
            y: 0
            radius: Styling.radius(4)

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: Icons.clock
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Styling.srItem("bg")
                }
                Text {
                    text: "21:30"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.DemiBold
                    color: Styling.srItem("bg")
                }
            }
        }

        GlassPanel {
            id: popup
            backdrop: wall.status === Image.Ready ? wall : fallback
            blurCfg: root.blurCfg
            blurAmount: root.blurAmount
            x: Math.max(16, scene.width * 0.08)
            y: 46
            width: Math.min(scene.width * 0.52, 360)
            height: Math.min(scene.height - y - 16, 180)

            Column {
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 8

                Text {
                    text: I18n.t("prefs.glass.preview.title")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(2)
                    font.weight: Font.Bold
                    color: Styling.srItem("popup")
                }
                Text {
                    width: parent.width
                    text: I18n.t("prefs.glass.preview.body")
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Styling.srItem("popup")
                }
                Row {
                    spacing: 8
                    StyledRect {
                        variant: "pane"
                        width: 92
                        height: 28
                        radius: Styling.radius(0)
                        Text {
                            anchors.centerIn: parent
                            text: Icons.wifiHigh + "  Wi-Fi"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Styling.srItem("pane")
                        }
                    }
                    StyledRect {
                        variant: "primary"
                        width: 64
                        height: 28
                        radius: Styling.radius(0)
                        Text {
                            anchors.centerIn: parent
                            text: "OK"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.weight: Font.Bold
                            color: Styling.srItem("primary")
                        }
                    }
                }
            }
        }

        // Readout: level + guaranteed contrast.
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            width: readout.implicitWidth + 20
            height: readout.implicitHeight + 12
            radius: Math.min(Styling.radius(0), 12)
            color: Ui.alpha(Colors.surfaceContainerLowest, 0.8)

            Column {
                id: readout
                anchors.centerIn: parent
                spacing: 2
                Text {
                    text: Math.round(Glass.amount * 100) + "% · " + I18n.t("prefs.glass.level." + Glass.describe(Glass.amount))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.Bold
                    color: Colors.overBackground
                }
                Text {
                    objectName: "glassContrast"
                    text: I18n.t("prefs.glass.preview.contrast").replace("%1", root.contrast.toFixed(1))
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: root.contrast >= 4.5 ? Colors.overSurfaceVariant : Colors.error
                }
            }
        }
    }

    // One glass panel: the blurred wallpaper under it + the surface.
    component GlassPanel: Item {
        id: panel
        property string variant: "popup"
        property string surface: "popups"
        property real radius: Styling.radius(4)
        property Item backdrop
        property var blurCfg: ({})
        property real blurAmount: 0
        default property alias content: surfaceRect.data

        ClippingRectangle {
            anchors.fill: parent
            radius: panel.radius
            color: "transparent"

            MultiEffect {
                x: -panel.x
                y: -panel.y
                width: panel.backdrop ? panel.backdrop.width : 0
                height: panel.backdrop ? panel.backdrop.height : 0
                source: panel.backdrop
                blurEnabled: panel.blurAmount > 0
                blur: panel.blurAmount
                blurMax: 48
                saturation: panel.blurCfg.vibrancy ?? 0
                brightness: (panel.blurCfg.brightness ?? 1) - 1
                contrast: (panel.blurCfg.contrast ?? 1) - 1
            }
        }

        StyledRect {
            id: surfaceRect
            anchors.fill: parent
            variant: panel.variant
            glassSurface: panel.surface
            radius: panel.radius
        }
    }
}
