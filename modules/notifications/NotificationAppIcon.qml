import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.components.kit
import "ToastModel.js" as ToastModel

// The leading art of a notification (notch cards, the dashboard history):
// the kit Art with the notification image, else the app icon, else the app
// initial (the alert glyph when critical). A themed icon the theme lacks
// resolves to nothing (Quickshell.iconPath(name, true)) so the placeholder
// shows instead of the theme's "image-missing" picture.
Art {
    id: root

    property string appIcon: ""
    property string appName: ""
    property string summary: ""
    property var urgency: 1
    property string image: ""
    property real size: Space.controlM
    readonly property var note: ({
            "appIcon": root.appIcon,
            "appName": root.appName,
            "summary": root.summary,
            "urgency": root.urgency,
            "image": root.image
        })
    readonly property var art: ToastModel.artOf(root.note, name => Quickshell.iconPath(name, true))

    implicitWidth: root.size
    implicitHeight: root.size
    source: root.art.source
    icon: ToastModel.isCritical(root.urgency) ? Icons.alert : Icons.bell
    placeholderText: ToastModel.initialOf(root.note)
}
