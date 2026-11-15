pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs.modules.theme
import qs.modules.globals
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.previews

// The hero of a settings page: a live miniature of the shell element the
// page controls, drawn over the user's wallpaper (the palette's backdrop
// while there is none) in a rounded frame. The page's stage file (schema
// category `stage`, Registry.STAGES) is a Stage with its miniature as
// children; parts mark the settings they show with StageSpot. `stageHeight`
// is the height it asks for; the page gives it the content width.
Item {
    id: stage

    property real stageHeight: Space.px(280)
    // Draw the wallpaper backdrop (false: the children draw their own).
    property bool backdrop: true
    // The wallpaper's zoom (a home tile drifts it a little while hovered).
    property real imageScale: 1
    // Parallax: the wallpaper's offset in px (a hovered home tile follows
    // the pointer a little).
    property point imageShift: Qt.point(0, 0)
    // A plain backdrop (the status band of a list page, with text and
    // controls on it): a card fill, no wallpaper picture at all.
    property bool calm: false
    // the hairline edge (false: the stage draws no frame of its own)
    property bool framed: true
    default property alias content: area.data
    property real radius: Look.radius("surface", stage.height)
    // The wallpaper as a file URL ("" while there is none): the picture
    // itself, decoded at the stage's size in device pixels (a thumbnail
    // upscaled reads blurry and blocky on a big stage).
    readonly property string wallpaper: SettingsStore.wallpaperSharp || SettingsStore.wallpaper

    implicitHeight: stage.stageHeight

    // The bar surface ("barbg") is drawn at least this opaque: a theme
    // whose bar has no background of its own (modules floating on the
    // wallpaper) still reads as a bar in the miniature.
    readonly property real barOpacity: Math.max(Number(SettingsStore.get("theme.srBarBg.opacity") ?? 1), 0.82)

    // Everything inside is drawn through the rounded mask.
    Item {
        id: canvas
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Item {
            id: lens
            anchors.fill: parent

            ScreenBackdrop {
                anchors.fill: parent
                radius: 0
                visible: stage.backdrop && !stage.calm
            }
            Image {
                id: picture
                anchors.fill: parent
                visible: stage.backdrop && !stage.calm
                // fades in once decoded (never pops over the backdrop)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    enabled: Motion.glide.duration > 0
                    NumberAnimation {
                        duration: Motion.glide.duration
                        easing.type: Motion.glide.easing
                    }
                }
                source: stage.calm ? "" : stage.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.max(1, Math.ceil(stage.width * Math.max(1, Screen.devicePixelRatio) * Math.max(1, stage.imageScale)))
                scale: stage.imageScale
                transform: Translate {
                    x: stage.imageShift.x
                    y: stage.imageShift.y
                    Behavior on x {
                        enabled: Motion.glide.duration > 0
                        NumberAnimation {
                            duration: Motion.glide.duration
                            easing.type: Motion.glide.easing
                        }
                    }
                    Behavior on y {
                        enabled: Motion.glide.duration > 0
                        NumberAnimation {
                            duration: Motion.glide.duration
                            easing.type: Motion.glide.easing
                        }
                    }
                }
                Behavior on scale {
                    enabled: Motion.pan.duration > 0
                    NumberAnimation {
                        duration: Motion.pan.duration
                        easing.type: Motion.pan.easing
                    }
                }
            }
            Mark {
                anchors.fill: parent
                radius: 0
                visible: stage.calm && stage.backdrop
                color: Look.cardFill(false)
            }
            Item {
                id: area
                anchors.fill: parent
            }
        }
    }

    Mark {
        id: mask
        anchors.fill: parent
        radius: stage.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // A hairline edge so the stage reads as a screen in every language.
    Mark {
        visible: stage.framed
        anchors.fill: parent
        radius: stage.radius
        color: "transparent"
        border.width: Space.hairline
        border.color: Type.hairline
    }
}
