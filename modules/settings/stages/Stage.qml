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
    default property alias content: area.data
    property real radius: Look.radius("surface", stage.height)
    // The wallpaper as a file URL ("" while there is none).
    readonly property string wallpaper: {
        const m = GlobalStates.wallpaperManager;
        if (!m)
            return "";
        const path = m.effectiveWallpaper ?? m.currentWallpaper ?? "";
        const shown = path && m.getDisplaySource ? m.getDisplaySource(path) : path;
        return shown ? (String(shown).startsWith("/") ? "file://" + shown : String(shown)) : "";
    }

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

        ScreenBackdrop {
            anchors.fill: parent
            radius: 0
            visible: stage.backdrop
        }
        Image {
            anchors.fill: parent
            visible: stage.backdrop && status === Image.Ready
            source: stage.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: Math.max(1, stage.width * 1.5)
            scale: stage.imageScale
            Behavior on scale {
                enabled: Motion.pan.duration > 0
                NumberAnimation {
                    duration: Motion.pan.duration
                    easing.type: Motion.pan.easing
                }
            }
        }
        Item {
            id: area
            anchors.fill: parent
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
