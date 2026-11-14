pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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
    default property alias content: area.data
    property real radius: Look.radius("surface", stage.height)
    // The wallpaper as a file URL ("" while there is none).
    readonly property string wallpaper: SettingsStore.wallpaper
    // The camera: the picture (wallpaper and miniature together) zoomed
    // by `zoom` around `lookAt` (a point in 0..1 of the stage), eased
    // when a page sets them (normalised: a resize never animates them).
    property real zoom: 1
    property point lookAt: Qt.point(0.5, 0.5)
    // false: the camera jumps (the first placement)
    property bool cameraEased: true

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
            transform: Scale {
                origin.x: stage.lookAt.x * lens.width
                origin.y: stage.lookAt.y * lens.height
                xScale: stage.zoom
                yScale: stage.zoom
            }

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
                sourceSize.width: Math.max(1, stage.width * 1.5)
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

    Behavior on zoom {
        enabled: stage.cameraEased && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.glide.easing
        }
    }
    Behavior on lookAt {
        enabled: stage.cameraEased && Motion.morph.duration > 0
        PropertyAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.glide.easing
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
        anchors.fill: parent
        radius: stage.radius
        color: "transparent"
        border.width: Space.hairline
        border.color: Type.hairline
    }
}
