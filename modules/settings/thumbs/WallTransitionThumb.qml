pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of a wallpaper transition (desktop.wallpaperTransition),
// caught halfway: the old picture (dimmed) giving way to the new one by
// the transition's shape: a growing circle, a wipe, dissolving blocks, an
// even fade, a die for random, a hard cut for none.
MiniScreen {
    desktop: true
    id: root

    property var entry
    property var value: "grow"
    // the old wallpaper over the new one where it still shows
    readonly property color old: Qt.alpha(Colors.shadow, 0.7)

    // grow: the new picture in a circle from the centre
    Item {
        anchors.fill: parent
        visible: root.value === "grow"
        Mark {
            anchors.fill: parent
            radius: 0
            color: root.old
        }
        Art {
            anchors.centerIn: parent
            width: root.height * 0.7
            height: width
            radius: width / 2
            source: root.wallpaper
        }
    }

    // wipe: the old picture slides off to the right
    Mark {
        visible: root.value === "wipe"
        x: root.width * 0.5
        width: root.width * 0.5
        height: root.height
        radius: 0
        color: root.old
        Mark {
            width: Space.stroke
            height: parent.height
            radius: 0
            color: Type.accent
        }
    }

    // dissolve: blocks of the old picture left here and there
    Grid {
        visible: root.value === "dissolve"
        anchors.fill: parent
        columns: 8
        Repeater {
            model: 40
            delegate: Mark {
                required property int index
                width: root.width / 8
                height: root.height / 5
                radius: 0
                // a fixed scatter (no randomness: the picture never changes)
                color: (index * 7 + Math.floor(index / 8) * 3) % 5 < 2 ? root.old : "transparent"
            }
        }
    }

    // fade: the old picture half gone everywhere
    Mark {
        visible: root.value === "fade"
        anchors.fill: parent
        radius: 0
        color: Qt.alpha(Colors.shadow, 0.4)
    }

    // random / none: a sign over the old picture
    Mark {
        visible: root.value === "random" || root.value === "none"
        anchors.fill: parent
        radius: 0
        color: root.value === "none" ? "transparent" : Qt.alpha(Colors.shadow, 0.35)
    }
    Icon {
        visible: root.value === "random" || root.value === "none"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.1
        icon: root.value === "random" ? Icons.shuffle : Icons.lightningBolt
        size: Math.round(root.height * 0.32)
        tone: "text"
    }
}
