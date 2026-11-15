pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live

// Card picture of where corner toasts stack (notifications.position): a
// small screen with the real toast (live/LiveToast: the shell's own card
// with the sample message, its stack when grouped by app) at that place
// (top / bottom, left / centre / right). Auto: the toast faint at the top
// right with a wand (the bar's side decides).
ThumbGround {
    id: root

    property var entry
    property var value: "auto"
    readonly property bool auto: root.value === "auto"
    readonly property string place: root.auto ? "top-right" : String(root.value)
    readonly property bool atBottom: root.place.indexOf("bottom") === 0
    readonly property string side: root.place.indexOf("left") >= 0 ? "left" : (root.place.indexOf("right") >= 0 ? "right" : "center")
    readonly property real unit: Math.min(root.width, root.height) / 10
    readonly property real toastW: Math.round(root.width * 0.42)
    // the toast's height at that width (its own proportions)
    readonly property real toastH: toast.part.partWidth > 0 ? Math.round(root.toastW * toast.part.partHeight / toast.part.partWidth) : Math.round(root.unit * 3)

    LiveToast {
        id: toast
        opacity: root.auto ? 0.45 : 1
        grouped: SettingsStore.get("notifications.groupByApp") === true
        stackUp: root.atBottom
        snapshot: true
        refreshKey: [String(Colors.primary), String(Colors.background), SettingsStore.get("theme.font")]
        width: root.toastW
        height: root.toastH
        x: root.side === "left" ? root.unit : root.side === "right" ? root.width - width - root.unit : Math.round((root.width - width) / 2)
        y: root.atBottom ? root.height - height - root.unit : root.unit
    }

    Icon {
        visible: root.auto
        anchors.centerIn: parent
        icon: Icons.magicWand
        role: "body"
        tone: "secondary"
    }
}
