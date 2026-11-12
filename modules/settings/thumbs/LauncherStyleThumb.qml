pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of a launcher result style (layout.launcher.resultStyle): a
// small launcher over the wallpaper with its results as a list of lines,
// as cards (taller rows, a second line) or as a grid of tiles.
MiniScreen {
    id: root

    property var entry
    property var value: "list"
    readonly property real pad: root.u * 3

    Mark {
        id: box
        x: root.width * 0.16
        y: root.height * 0.1
        width: root.width * 0.68
        height: root.height * 0.66
        radius: root.u * 4
        color: Qt.alpha(Colors.background, 0.92)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)

        // the field
        Mark {
            x: root.pad
            y: root.pad
            width: box.width - root.pad * 2
            height: root.u * 7
            radius: height / 2
            color: Look.raisedFill(false)
        }

        // list / cards
        Column {
            visible: root.value !== "grid"
            x: root.pad
            y: root.pad * 2 + root.u * 7
            spacing: root.u * (root.value === "cards" ? 2 : 1.6)
            Repeater {
                model: root.value === "cards" ? 2 : 3
                delegate: Mark {
                    required property int index
                    width: box.width - root.pad * 2
                    height: root.u * (root.value === "cards" ? 9 : 5)
                    radius: root.u * 2
                    color: index === 0 ? Qt.alpha(Type.accent, 0.3) : (root.value === "cards" ? Look.raisedFill(false) : "transparent")
                    Mark {
                        x: root.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.u * (root.value === "cards" ? 6 : 3.4)
                        height: width
                        radius: root.u * 1.4
                        color: index === 0 ? Type.accent : Qt.alpha(Type.text, 0.5)
                    }
                    Column {
                        x: root.u * (root.value === "cards" ? 10 : 7)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.u * 1.2
                        Mark {
                            width: box.width * 0.4
                            height: Math.max(2, root.u * 1.4)
                            color: Qt.alpha(Type.text, 0.7)
                        }
                        Mark {
                            visible: root.value === "cards"
                            width: box.width * 0.26
                            height: Math.max(2, root.u * 1.1)
                            color: Qt.alpha(Type.text, 0.35)
                        }
                    }
                }
            }
        }

        // grid
        Grid {
            visible: root.value === "grid"
            x: root.pad
            y: root.pad * 2 + root.u * 7
            columns: 4
            spacing: root.u * 1.6
            Repeater {
                model: 8
                delegate: Mark {
                    required property int index
                    width: (box.width - root.pad * 2 - root.u * 1.6 * 3) / 4
                    height: width * 0.72
                    radius: root.u * 2
                    color: index === 0 ? Qt.alpha(Type.accent, 0.3) : Look.raisedFill(false)
                    Mark {
                        anchors.centerIn: parent
                        width: parent.height * 0.45
                        height: width
                        radius: root.u
                        color: index === 0 ? Type.accent : Qt.alpha(Type.text, 0.5)
                    }
                }
            }
        }
    }
}
