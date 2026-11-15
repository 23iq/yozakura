import QtQuick
import qs.modules.components.kit

// The small screen several home tile scenes draw on (Windows, Panels): a
// 16:10 frame fitted and centred in its parent, in the language's well (a
// recessed panel of the card), with a hairline edge. Children are in screen
// coordinates and clipped to it (`screenWidth` x `screenHeight`).
Item {
    id: frame

    default property alias content: inner.data
    readonly property real aspect: 16 / 10
    readonly property real screenWidth: Math.round(Math.min(frame.width, frame.height * frame.aspect))
    readonly property real screenHeight: Math.round(frame.screenWidth / frame.aspect)
    readonly property real radius: Look.radius("small", frame.screenHeight)

    Mark {
        id: box
        x: Math.round((frame.width - width) / 2)
        y: Math.round((frame.height - height) / 2)
        width: frame.screenWidth
        height: frame.screenHeight
        radius: frame.radius
        color: Look.alpha("overBackground", 0.05)
        border.width: Space.hairline
        border.color: Type.hairline
        clip: true

        Item {
            id: inner
            anchors.fill: parent
        }
    }
}
