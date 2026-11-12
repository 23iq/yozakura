import QtQuick

// Holds captured shadows (ShadowCaster: bar panels, live activities) in
// screen coordinates, cut to `hole` (the bounding box of the screen frame's
// hole) while `clipped`: the frame is drawn by its own window below
// (performance.splitFrame), so a shadow must stop where the frame would
// have covered it. Not clipped, a plain item the size of `area`.
Item {
    id: root

    property bool clipped: false
    property rect hole: Qt.rect(0, 0, 0, 0)
    // The full-size item the shadows' coordinates are relative to
    property Item area: null
    default property alias content: inner.data

    x: root.clipped ? root.hole.x : 0
    y: root.clipped ? root.hole.y : 0
    width: root.clipped ? root.hole.width : (root.area ? root.area.width : 0)
    height: root.clipped ? root.hole.height : (root.area ? root.area.height : 0)
    clip: root.clipped

    Item {
        id: inner
        x: -root.x
        y: -root.y
        width: root.area ? root.area.width : 0
        height: root.area ? root.area.height : 0
    }
}
