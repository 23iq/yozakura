pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// What a window of the Windows stage shows (WindowsStage's TiledWindow):
// title dots, then an editor (`kind` 0), a gallery (1), a player (2) or a
// chat (3), its shapes rounded with the window (`rounding`).
Item {
    id: app

    property int kind: 0
    property real rounding: 0

    clip: true

    Row {
        id: dots
        spacing: Space.xs
        Repeater {
            model: 3
            delegate: Mark {
                required property int index
                width: Space.s
                height: Space.s
                color: [Colors.error, Colors.tertiary, Colors.primary][index]
                opacity: 0.8
            }
        }
    }

    // editor: lines in a few syntax colours
    Column {
        visible: app.kind === 0
        y: dots.height + Space.m
        spacing: Space.s
        Repeater {
            model: [[0, 0.32, 1], [1, 0.5, 0], [1, 0.62, 2], [2, 0.4, 0], [1, 0.56, 1], [1, 0.28, 0], [0, 0.18, 2], [0, 0.44, 1], [1, 0.36, 0]]
            delegate: Mark {
                required property var modelData
                x: modelData[0] * Space.l
                width: modelData[1] * app.width
                height: Space.xs + 1
                color: Qt.alpha([Type.text, Colors.primary, Colors.tertiary][modelData[2]], modelData[2] === 0 ? 0.2 : 0.55)
            }
        }
    }

    // gallery: a grid of tinted pictures
    Grid {
        id: gallery
        visible: app.kind === 1
        y: dots.height + Space.s
        columns: 3
        spacing: Space.xs
        readonly property real cell: (app.width - spacing * 2) / 3
        Repeater {
            model: 6
            delegate: Mark {
                required property int index
                width: gallery.cell
                height: Math.min(gallery.cell * 0.7, (app.height - dots.height - Space.s * 2) / 2)
                radius: Math.min(app.rounding * 0.5, Space.smallRadius)
                color: Qt.alpha([Colors.primary, Colors.tertiary, Colors.secondary][index % 3], 0.18 + (index % 2) * 0.14)
            }
        }
    }

    // player: cover, two lines and the progress
    Row {
        visible: app.kind === 2
        y: dots.height + Space.s
        spacing: Space.m
        Mark {
            width: Math.min(app.height - dots.height - Space.s, Space.xxl + Space.l)
            height: width
            radius: Math.min(app.rounding * 0.6, width / 2)
            color: Qt.alpha(Colors.primary, 0.45)
        }
        Column {
            spacing: Space.s
            anchors.verticalCenter: parent.verticalCenter
            Mark {
                width: app.width * 0.36
                height: Space.xs + 2
                color: Qt.alpha(Type.text, 0.45)
            }
            Mark {
                width: app.width * 0.24
                height: Space.xs + 1
                color: Qt.alpha(Type.text, 0.2)
            }
            Mark {
                width: app.width * 0.46
                height: Space.xs - 1
                color: Type.track
                Mark {
                    width: parent.width * 0.38
                    height: parent.height
                    color: Colors.primary
                }
            }
        }
    }

    // chat: bubbles on both sides
    Column {
        visible: app.kind === 3
        y: dots.height + Space.s
        width: app.width
        spacing: Space.xs + 2
        Repeater {
            model: [[0, 0.6], [1, 0.42], [0, 0.34]]
            delegate: Mark {
                required property var modelData
                x: modelData[0] === 1 ? app.width - width : 0
                width: app.width * modelData[1]
                height: Space.l
                radius: Math.min(app.rounding * 0.5 + Space.xs, height / 2)
                color: modelData[0] === 1 ? Qt.alpha(Colors.primary, 0.4) : Qt.alpha(Type.text, 0.1)
            }
        }
    }
}
