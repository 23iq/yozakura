import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The one-line instruction under a stage ("Click a bar..."), quiet: it
// shows only while the pointer is over the stage it explains (`shown`,
// the page binds it to a HoverHandler of the stage) and fades in and out
// (glide). Its line is always kept, so nothing moves when it shows. Every
// stage hint of the window uses it (schema pages and the hand-written
// Displays, Keyboard and Presets pages).
KitText {
    id: hint

    property bool shown: false

    objectName: "heroHint"
    horizontalAlignment: Text.AlignHCenter
    role: "caption"
    color: Type.muted
    opacity: hint.shown ? 1 : 0
    Behavior on opacity {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }
}
