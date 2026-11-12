import QtQuick

// The Settings window of the shell (shell.qml, KeepAliveLoader): the window
// (SettingsWindow) and its content, compiled with it when the loader loads
// this file asynchronously.
SettingsWindow {
    id: settingsWindow

    SettingsShell {
        anchors.fill: parent
        // While kept alive hidden (KeepAliveLoader), the pages see
        // visible=false: previews, polls and timers gated on it stop.
        visible: settingsWindow.visible
    }
}
