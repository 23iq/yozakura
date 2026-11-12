import QtQuick
import qs.config

// The Settings window of a separate Settings process (settings-window.qml,
// performance.separateWindows): the frame maps at once with the window
// background (SettingsLoading); the content is loaded by URL, compiled and
// built asynchronously behind it.
SettingsWindow {
    id: settingsWindow

    readonly property bool contentReady: content.status === Loader.Ready

    // Built once this process has read the config files (the pages
    // must never start from the defaults).
    Loader {
        id: content
        anchors.fill: parent
        active: Config.initialLoadComplete
        asynchronous: true
        source: "SettingsShell.qml"
        visible: settingsWindow.visible
    }

    SettingsLoading {
        anchors.fill: parent
        visible: !settingsWindow.contentReady
    }
}
