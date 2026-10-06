pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.theme
import qs.modules.globals
import qs.config

// Settings > Shell > Bar: the "Live Activities" group (bar.json
// "activities": master switch, presentation, max visible islands, download
// grouping/speed, per-source toggles). Endpoints/secrets of local services
// (torrent clients, aria2, Syncthing) are edited in bar.json.
ColumnLayout {
    id: group

    spacing: 8

    readonly property var current: Config.bar.activities ? Config.bar.activities : ({})
    readonly property bool masterEnabled: group.current.enabled ?? true

    // "activities" is one JSON object: copy, change one field, reassign.
    // `section` names a nested object ("sources", "downloads").
    function setField(field, value, section) {
        const next = JSON.parse(JSON.stringify(Config.bar.activities || {}));
        const target = section ? (next[section] = next[section] || {}) : next;
        if (target[field] === value)
            return;
        target[field] = value;
        GlobalStates.markShellChanged();
        Config.bar.activities = next;
    }

    readonly property var downloads: group.current.downloads || ({})

    Text {
        text: I18n.t("shell.activities")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.Medium
        color: Colors.overSurfaceVariant
        Layout.bottomMargin: -4
    }

    SettingsToggleRow {
        label: I18n.t("shell.activities_enabled")
        checked: group.masterEnabled
        onToggled: value => group.setField("enabled", value)
    }

    SettingsSelectorRow {
        label: I18n.t("shell.activities_presentation")
        enabled: group.masterEnabled
        options: [
            {
                label: I18n.t("shell.activities_presentation_notch"),
                value: "notch"
            },
            {
                label: I18n.t("shell.activities_presentation_islands"),
                value: "islands"
            },
            {
                label: I18n.t("shell.activities_presentation_off"),
                value: "off"
            }
        ]
        value: group.current.presentation ?? "notch"
        onValueSelected: newValue => group.setField("presentation", newValue)
    }

    SettingsNumberRow {
        label: I18n.t("shell.activities_max_visible")
        enabled: group.masterEnabled
        value: group.current.maxVisible ?? 4
        minValue: 1
        maxValue: 8
        onValueEdited: newValue => group.setField("maxVisible", newValue)
    }

    SettingsToggleRow {
        label: I18n.t("shell.activities_aggregate")
        enabled: group.masterEnabled
        checked: group.downloads.aggregate ?? true
        onToggled: value => group.setField("aggregate", value, "downloads")
    }

    SettingsToggleRow {
        label: I18n.t("shell.activities_show_speed")
        enabled: group.masterEnabled
        checked: group.downloads.showSpeed ?? true
        onToggled: value => group.setField("showSpeed", value, "downloads")
    }

    Repeater {
        model: [
            {
                key: "recording",
                label: "shell.activities_recording"
            },
            {
                key: "privacy",
                label: "shell.activities_privacy"
            },
            {
                key: "timers",
                label: "shell.activities_timers"
            },
            {
                key: "tasks",
                label: "shell.activities_tasks"
            },
            {
                key: "notificationProgress",
                label: "shell.activities_notification_progress"
            },
            {
                key: "browserDownloads",
                label: "shell.activities_browser"
            },
            {
                key: "jobView",
                label: "shell.activities_jobview"
            },
            {
                key: "steam",
                label: "shell.activities_steam"
            },
            {
                key: "terminal",
                label: "shell.activities_terminal"
            },
            {
                key: "fileOps",
                label: "shell.activities_fileops"
            },
            {
                key: "packages",
                label: "shell.activities_packages"
            },
            {
                key: "torrents",
                label: "shell.activities_torrents"
            },
            {
                key: "aria2",
                label: "shell.activities_aria2"
            },
            {
                key: "syncthing",
                label: "shell.activities_syncthing"
            },
            {
                key: "launchers",
                label: "shell.activities_launchers"
            }
        ]
        delegate: SettingsToggleRow {
            required property var modelData
            label: I18n.t(modelData.label)
            enabled: group.masterEnabled
            checked: (group.current.sources || {})[modelData.key] ?? true
            onToggled: value => group.setField(modelData.key, value, "sources")
        }
    }
}
