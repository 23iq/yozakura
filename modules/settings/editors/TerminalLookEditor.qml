import QtQuick

// Settings > Apps > Terminal, "More": the full prompt view (live kitty
// preview, what keeps the prompt from showing and the action that fixes it:
// install the engine or a Nerd Font, make fish the login shell, a foreign
// prompt in config.fish; the prompt gallery with descriptions;
// modules/terminal/TerminalLookSection, shared with onboarding). Created by
// URL the first time the sheet shows it, so the page never pays for it.
Item {
    id: root

    property var entry
    property bool seen: false

    implicitHeight: loader.item ? (loader.item as Item).implicitHeight : 0
    onVisibleChanged: if (visible)
        root.seen = true
    Component.onCompleted: root.seen = root.visible

    Loader {
        id: loader
        width: root.width
        active: root.seen
        asynchronous: true
        source: Qt.resolvedUrl("../../terminal/TerminalLookSection.qml")
    }
}
