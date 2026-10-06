import QtQuick
import qs.modules.theme
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel

// Status glyph of a task or run: a spinner while it works, a pulsing hand
// while it waits for the user, the status icon otherwise.
Item {
    id: root

    property string status: ""
    property int size: 0
    readonly property var info: TaskModel.statusInfo(status)

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    Spinner {
        anchors.centerIn: parent
        running: root.info.busy
        font.pixelSize: BarLook.font(root.size)
    }
    Glyph {
        id: glyph
        anchors.centerIn: parent
        visible: !root.info.busy
        size: root.size
        role: root.info.color
        text: Icons[root.info.icon] || Icons.circle
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
