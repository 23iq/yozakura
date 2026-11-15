import QtQuick
import qs.config
import qs.modules.theme

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

    // fades away over the content once it is there (a cross-fade, not a cut)
    SettingsLoading {
        anchors.fill: parent
        opacity: settingsWindow.contentReady ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }
}
