pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// The colours the wallpaper gives the shell: the palette's swatches (live:
// a new wallpaper repaints them) and the scheme that derives them, a chip
// that opens Look's palette to change it. With a colour preset active the
// chip names the preset instead (the wallpaper does not colour the shell).
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property string scheme: String(SettingsStore.get("wallpaper.matugenScheme") || "scheme-tonal-spot")
    readonly property string preset: String(SettingsStore.get("wallpaper.activeColorPreset") || "")
    readonly property var swatches: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.primaryContainer, Colors.surfaceContainerHigh]

    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.px(140)

    Row {
        id: swatchRow
        objectName: "wallpaperSwatches"
        width: root.width
        height: root.height - link.height - Space.m
        spacing: Space.s
        Repeater {
            model: root.swatches
            delegate: Mark {
                required property color modelData
                width: (swatchRow.width - swatchRow.spacing * (root.swatches.length - 1)) / root.swatches.length
                height: swatchRow.height
                radius: Look.radius("box", width)
                color: modelData
                border.width: Space.hairline
                border.color: Type.hairline
                Behavior on color {
                    enabled: Motion.glide.duration > 0
                    ColorAnimation {
                        duration: Motion.glide.duration
                    }
                }
            }
        }
    }

    Chip {
        id: link
        objectName: "wallpaperSchemeLink"
        anchors.bottom: parent.bottom
        dense: true
        icon: root.preset ? Icons.palette : Icons.drop
        trailingIcon: Icons.caretRight
        text: root.preset ? root.preset : I18n.t("wallpapers.scheme_" + root.scheme.replace("scheme-", "").replace(/-/g, "_"))
        onClicked: SettingsStore.navigate("appearance", "palette", "wallpaper.matugenScheme")
    }
}
