pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import "../Ui.js" as Ui

// Tiny desktop mock (wallpaper glow, bar, a window) drawn with an arbitrary
// palette ({role: color}); missing roles fall back to the live Colors.
Item {
    id: root

    property var colorMap: null
    property bool oled: false
    readonly property real s: Math.min(width / 200, height / 110)

    function c(role) {
        const p = colorMap;
        if (p && p[role])
            return typeof p[role] === "string" ? Qt.color(p[role]) : p[role];
        return Colors[role] ?? "transparent";
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Math.min(Styling.radius(0), 14)
        color: root.oled ? "#000000" : root.c("background")
        clip: true

        // Wallpaper glow
        Rectangle {
            x: parent.width * 0.42
            y: -parent.height * 0.35
            width: parent.width * 0.9
            height: width
            radius: width / 2
            opacity: root.oled ? 0.35 : 0.6
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Ui.alpha(root.c("primary"), 0.55)
                }
                GradientStop {
                    position: 0.6
                    color: Ui.alpha(root.c("tertiary"), 0.18)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        // Bar
        Rectangle {
            x: 6 * root.s
            y: 5 * root.s
            width: parent.width - 12 * root.s
            height: 11 * root.s
            radius: height / 2
            color: root.oled ? "#000000" : root.c("surfaceContainer")
            border.width: root.oled ? 1 : 0
            border.color: root.c("outlineVariant")

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.5 * root.s
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: index === 0 ? 9 * root.s : 4 * root.s
                        height: 4 * root.s
                        radius: height / 2
                        color: index === 0 ? root.c("primary") : Ui.alpha(root.c("overSurfaceVariant"), 0.6)
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 4 * root.s
                radius: height / 2
                color: Ui.alpha(root.c("overBackground"), 0.7)
            }
        }

        // Window
        Rectangle {
            x: 16 * root.s
            y: 24 * root.s
            width: parent.width * 0.62
            height: parent.height - 32 * root.s
            radius: Math.min(Styling.radius(0) * 0.6, 10) * Math.max(root.s, 0.6)
            color: root.oled ? "#0b0b0b" : root.c("surfaceContainerHigh")
            border.width: 1
            border.color: Ui.alpha(root.c("outlineVariant"), 0.8)

            Column {
                x: 7 * root.s
                y: 7 * root.s
                spacing: 4 * root.s
                Rectangle {
                    width: 46 * root.s
                    height: 5 * root.s
                    radius: height / 2
                    color: root.c("overBackground")
                }
                Rectangle {
                    width: 70 * root.s
                    height: 3.5 * root.s
                    radius: height / 2
                    color: Ui.alpha(root.c("overSurfaceVariant"), 0.55)
                }
                Rectangle {
                    width: 58 * root.s
                    height: 3.5 * root.s
                    radius: height / 2
                    color: Ui.alpha(root.c("overSurfaceVariant"), 0.55)
                }
                Row {
                    spacing: 4 * root.s
                    Rectangle {
                        width: 26 * root.s
                        height: 10 * root.s
                        radius: height / 2
                        color: root.c("primary")
                    }
                    Rectangle {
                        width: 20 * root.s
                        height: 10 * root.s
                        radius: height / 2
                        color: root.c("secondaryContainer")
                    }
                }
            }
        }

        // Accent dots
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 10 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9 * root.s
            spacing: 3 * root.s
            Repeater {
                model: ["primary", "secondary", "tertiary"]
                Rectangle {
                    required property string modelData
                    width: 9 * root.s
                    height: width
                    radius: width / 2
                    color: root.c(modelData)
                }
            }
        }
    }
}
