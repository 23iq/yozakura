import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../Ui.js" as Ui

// Depth clock status under the video toggle: progress of the matte video
// being built for the current video wallpaper, or how to enable depth
// (the mask model is not installed).
Item {
    id: root

    property var entry
    readonly property bool clockOn: !!SettingsStore.get("desktop.depthClock")
    readonly property bool building: clockOn && !!SettingsStore.get("desktop.depthClockVideo") && DepthMaskService.matteJob !== ""
    readonly property bool missing: clockOn && !DepthMaskService.available

    visible: building || missing
    implicitHeight: visible ? column.implicitHeight + 4 : 0

    Column {
        id: column
        width: parent.width
        spacing: 6

        Text {
            width: parent.width
            text: root.building ? I18n.t("shell.desktop.depth_clock_video_progress", Math.round(DepthMaskService.matteProgress * 100)) : I18n.t("shell.desktop.depth_clock_setup_hint")
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }

        Rectangle {
            visible: root.building
            width: parent.width
            height: 6
            radius: 3
            color: Ui.alpha(Colors.overBackground, 0.1)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, DepthMaskService.matteProgress))
                height: parent.height
                radius: 3
                color: Colors.primary
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.morph.duration
                    }
                }
            }
        }
    }
}
