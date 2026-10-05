import QtQuick
import qs.modules.desktop.widgets

// A placed widget rendered for real (WidgetFrame in preview mode: no
// persistence, no controls) at its size on its screen, scaled to fit.
Item {
    id: root

    property var widget: null
    property real screenW: 2560
    property real screenH: 1440

    readonly property real frameW: widget ? Math.max(1, widget.w * screenW) : 1
    readonly property real frameH: widget ? Math.max(1, widget.h * screenH) : 1
    readonly property real fit: Math.min(width / frameW, height / frameH, 1)

    clip: true

    Item {
        width: root.frameW
        height: root.frameH
        x: (root.width - width * root.fit) / 2
        y: (root.height - height * root.fit) / 2
        scale: root.fit
        transformOrigin: Item.TopLeft

        WidgetFrame {
            widget: root.widget ? Object.assign({}, root.widget, {
                x: 0,
                y: 0
            }) : null
            screenW: root.screenW
            screenH: root.screenH
            preview: true
            active: root.visible
        }
    }
}
