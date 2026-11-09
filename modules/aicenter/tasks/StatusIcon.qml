import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel

// Status glyph of a task or run: a spinner while it works, a pulsing hand
// while it waits for the user, the status icon otherwise; `role` is the
// Type role of the text it sits next to.
Item {
    id: root

    property string status: ""
    property string role: "body"
    readonly property var info: TaskModel.statusInfo(status)

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    Spinner {
        anchors.centerIn: parent
        running: root.info.busy
        font.pixelSize: BarLook.size(root.role)
    }
    Icon {
        id: glyph
        anchors.centerIn: parent
        visible: !root.info.busy
        role: root.role
        size: BarLook.size(root.role)
        color: Colors[root.info.color] ?? Type.text
        icon: Icons[root.info.icon] || Icons.circle
        SequentialAnimation on opacity {
            running: root.info.section === "waiting"
            loops: Animation.Infinite
            onStopped: glyph.opacity = 1
            NumberAnimation {
                to: 0.35
                duration: 700
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 700
                easing.type: Easing.InOutSine
            }
        }
    }
}
