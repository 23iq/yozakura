pragma ComponentBehavior: Bound

import QtQuick

// The full desktop widgets editor (DesktopWidgetsEditor: arrange on the
// desktop, each widget's options and screen) as it sits in the page's
// "More" sheet: created by URL the first time it is shown, off the frame,
// so opening the Widgets page never pays for it.
Item {
    id: root

    property var entry
    property bool seen: false

    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    onVisibleChanged: if (visible)
        root.seen = true
    Component.onCompleted: root.seen = root.visible

    Loader {
        id: loader
        width: root.width
        active: root.seen
        asynchronous: true
        source: Qt.resolvedUrl("DesktopWidgetsEditor.qml")
        onLoaded: item.entry = root.entry
    }
}
