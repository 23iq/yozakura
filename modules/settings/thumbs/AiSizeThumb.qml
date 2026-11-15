pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store

// Card picture of the Assistant's size (ai.appearance.defaultSize): the
// panel on your wallpaper as a sidebar (compact), half the screen (wide) or
// all of it (fullscreen), on its configured side.
MiniScreen {
    id: root

    property var entry
    property var value: "compact"
    readonly property bool onLeft: SettingsStore.get("ai.sidebarPosition") === "left"
    readonly property real share: root.value === "fullscreen" ? 1 : (root.value === "wide" ? 0.58 : 0.36)

    Mark {
        id: panel
        readonly property real m: root.u * 3
        width: Math.round((root.width - m * 2) * root.share)
        height: root.height - m * 2
        x: root.onLeft || root.value === "fullscreen" ? m : root.width - width - m
        y: m
        radius: Math.round(root.u * 4)
        color: Qt.alpha(Colors.surfaceContainer, 0.94)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)

        // two lines of chat and the field
        Column {
            x: Math.round(root.u * 3)
            y: Math.round(root.u * 4)
            width: panel.width - x * 2
            spacing: Math.round(root.u * 3)
            Mark {
                anchors.right: parent.right
                width: parent.width * 0.6
                height: Math.max(3, Math.round(root.u * 4))
                radius: height / 2
                color: Qt.alpha(Type.accent, 0.5)
            }
            Mark {
                width: parent.width * 0.8
                height: Math.max(3, Math.round(root.u * 4))
                radius: height / 2
                color: Qt.alpha(Type.text, 0.25)
            }
        }
        Mark {
            x: Math.round(root.u * 2.5)
            width: panel.width - x * 2
            height: Math.max(4, Math.round(root.u * 6))
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.u * 3)
            radius: height / 2
            color: Qt.alpha(Type.text, 0.12)
        }
    }
}
