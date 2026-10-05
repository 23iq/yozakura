import QtQuick
import QtQuick.Layouts
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import "../../../desktop/clockstyles/ClockStyleRegistry.js" as ClockStyles

// Desktop depth clock settings: toggle, style, position, setup hint.
ColumnLayout {
    id: depthClockSettings

    readonly property bool clockOn: Config.desktop.depthClock ?? false

    function apply(key: string, value: var) {
        if (value !== Config.desktop[key]) {
            GlobalStates.markShellChanged();
            Config.desktop[key] = value;
        }
    }

    Layout.fillWidth: true
    spacing: 8

    SettingsToggleRow {
        label: I18n.t("shell.desktop.depth_clock")
        checked: depthClockSettings.clockOn
        onToggled: value => depthClockSettings.apply("depthClock", value)
    }

    SettingsSelectorRow {
        label: I18n.t("shell.desktop.depth_clock_style")
        visible: depthClockSettings.clockOn
        options: ClockStyles.styles.map(s => ({
                    label: I18n.t(s.labelKey),
                    value: s.id,
                    icon: Icons[s.icon] ?? ""
                }))
        value: ClockStyles.get(Config.desktop.depthClockStyle).id
        onValueSelected: newValue => depthClockSettings.apply("depthClockStyle", newValue)
    }

    SettingsSelectorRow {
        label: I18n.t("shell.desktop.depth_clock_position")
        visible: depthClockSettings.clockOn
        options: [
            {
                label: I18n.t("common.auto"),
                value: "auto",
                icon: Icons.magicWand
            },
            {
                label: I18n.t("shell.desktop.depth_clock_left"),
                value: "left",
                icon: Icons.alignLeft
            },
            {
                label: I18n.t("shell.desktop.depth_clock_right"),
                value: "right",
                icon: Icons.alignRight
            }
        ]
        value: Config.desktop.depthClockPosition ?? "auto"
        onValueSelected: newValue => depthClockSettings.apply("depthClockPosition", newValue)
    }

    SettingsToggleRow {
        label: I18n.t("shell.desktop.depth_clock_video")
        visible: depthClockSettings.clockOn
        checked: Config.desktop.depthClockVideo ?? true
        onToggled: value => depthClockSettings.apply("depthClockVideo", value)
    }

    Text {
        Layout.fillWidth: true
        visible: depthClockSettings.clockOn && (Config.desktop.depthClockVideo ?? true) && DepthMaskService.matteJob !== ""
        text: I18n.t("shell.desktop.depth_clock_video_progress", Math.round(DepthMaskService.matteProgress * 100))
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
    }

    Text {
        Layout.fillWidth: true
        visible: depthClockSettings.clockOn && !DepthMaskService.available
        text: I18n.t("shell.desktop.depth_clock_setup_hint")
        wrapMode: Text.WordWrap
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        color: Colors.overSurfaceVariant
    }
}
