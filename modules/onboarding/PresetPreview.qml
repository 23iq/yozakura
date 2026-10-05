pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config
import "../settings/Ui.js" as Ui

// Static miniature of a desktop in a preset's look (OnboardingModel
// presetLook): the user's wallpaper, the bar on its edge as a full strip
// (classic) or floating islands, the frame, two windows with the preset's
// roundness and a light/dark/OLED surface tone. Palette roles come from
// the current scheme (presets recolor from the wallpaper anyway).
Item {
    id: root

    property var look: ({})
    property string wallpaper: ""

    readonly property real k: width / 320
    readonly property bool vertical: look.position === "left" || look.position === "right"
    readonly property real thick: Math.max(6, Math.round(13 * k))
    readonly property real r: Math.max(0, (look.roundness ?? 12) * 0.45 * k)
    // Palette ends by brightness, whatever the current scheme is.
    readonly property bool bgIsLight: Colors.background.hslLightness > Colors.overBackground.hslLightness
    readonly property color lightEnd: bgIsLight ? Colors.background : Colors.overBackground
    readonly property color darkEnd: bgIsLight ? Colors.overBackground : Colors.background
    readonly property color surface: look.light ? Ui.mix(lightEnd, Colors.primary, 0.06) : (look.oled ? Qt.rgba(0, 0, 0, 1) : Ui.mix(darkEnd, Colors.primary, 0.05)) // OLED: true black
    readonly property color ink: look.light ? darkEnd : lightEnd
    readonly property bool islands: look.style === "islands"
    readonly property real frameW: look.frame ? Math.max(2, Math.round(4 * k)) : 0

    clip: true

    Rectangle {
        anchors.fill: parent
        color: Colors.surfaceContainer
    }
    Image {
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 480
    }

    // Frame around the screen.
    Rectangle {
        visible: root.look.frame === true
        anchors.fill: parent
        color: "transparent"
        border.width: root.frameW
        border.color: Ui.alpha(root.surface, 0.92)
    }

    // Content area (inside bar + frame): two windows.
    Item {
        id: content
        anchors.fill: parent
        anchors.topMargin: root.frameW + (root.look.position === "top" ? root.thick + 4 * root.k : 6 * root.k)
        anchors.bottomMargin: root.frameW + (root.look.position === "bottom" ? root.thick + 4 * root.k : 6 * root.k)
        anchors.leftMargin: root.frameW + (root.look.position === "left" ? root.thick + 4 * root.k : 6 * root.k)
        anchors.rightMargin: root.frameW + (root.look.position === "right" ? root.thick + 4 * root.k : 6 * root.k)

        Repeater {
            model: 2
            delegate: Rectangle {
                id: win
                required property int index
                x: index === 0 ? 0 : content.width * 0.58 + 3 * root.k
                y: 0
                width: index === 0 ? content.width * 0.58 - 3 * root.k : content.width * 0.42 - 3 * root.k
                height: content.height
                radius: root.r
                color: Ui.alpha(root.surface, 0.82)
                border.width: index === 0 ? Math.max(1, root.k) : 0
                border.color: Ui.alpha(Colors.primary, 0.85)
                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8 * root.k
                    spacing: 5 * root.k
                    Repeater {
                        model: win.index === 0 ? 4 : 3
                        delegate: Rectangle {
                            required property int index
                            width: win.width * (index === 0 ? 0.45 : 0.7 - index * 0.12)
                            height: Math.max(2, 4 * root.k)
                            radius: height / 2
                            color: index === 0 ? Colors.primary : Ui.alpha(root.ink, 0.28)
                        }
                    }
                }
            }
        }
    }

    // Bar: one strip (classic) or three islands along the edge.
    Item {
        id: bar
        x: root.look.position === "right" ? parent.width - width - root.frameW - (root.islands ? 4 * root.k : 0) : root.frameW + (root.islands ? 4 * root.k : 0)
        y: root.look.position === "bottom" ? parent.height - height - root.frameW - (root.islands ? 4 * root.k : 0) : root.frameW + (root.islands ? 4 * root.k : 0)
        width: root.vertical ? root.thick : parent.width - 2 * root.frameW - (root.islands ? 8 * root.k : 0)
        height: root.vertical ? parent.height - 2 * root.frameW - (root.islands ? 8 * root.k : 0) : root.thick

        Rectangle {
            visible: !root.islands
            anchors.fill: parent
            color: Ui.alpha(root.surface, 0.94)
            radius: root.look.frame ? 0 : Math.min(root.r * 0.4, height / 2)
        }

        Repeater {
            model: root.islands ? [[0, 0.26], [0.36, 0.28], [0.78, 0.22]] : [[0.02, 0.14], [0.43, 0.14], [0.8, 0.18]]
            delegate: Rectangle {
                required property var modelData
                readonly property real len: root.vertical ? bar.height : bar.width
                x: root.vertical ? (root.islands ? 0 : bar.width * 0.25) : len * modelData[0]
                y: root.vertical ? len * modelData[0] : (root.islands ? 0 : bar.height * 0.25)
                width: root.vertical ? (root.islands ? bar.width : bar.width * 0.5) : len * modelData[1]
                height: root.vertical ? len * modelData[1] : (root.islands ? bar.height : bar.height * 0.5)
                radius: Math.min(Math.min(width, height) / 2, root.islands ? root.r : root.r * 0.5)
                color: root.islands ? Ui.alpha(root.surface, 0.94) : Ui.alpha(Colors.primary, 0.75)
                Rectangle {
                    visible: root.islands
                    anchors.centerIn: parent
                    width: root.vertical ? parent.width * 0.4 : parent.width * 0.55
                    height: root.vertical ? parent.height * 0.55 : parent.height * 0.4
                    radius: Math.min(width, height) / 2
                    color: Ui.alpha(Colors.primary, 0.8)
                }
            }
        }
    }
}
