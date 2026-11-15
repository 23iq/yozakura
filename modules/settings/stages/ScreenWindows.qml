pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings

// ScreenMini's windows: two windows in the space the bars, the frame and the
// dock leave (`free`: {x, y, w, h} in the miniature, the reserved space made
// visible), a title line and a few text lines each. They glide when a bar or
// the dock moves and land at once when the miniature (`frame`) is resized;
// `shown` fades and slides them in or out, to `shownOpacity`.
Item {
    id: windows

    required property Item frame
    property var free: ({
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0
        })
    property real unit: Space.px(16)
    property bool shown: true
    property real shownOpacity: 1

    readonly property real gap: Math.round(windows.unit * 0.5)
    visible: opacity > 0
    opacity: windows.shown ? windows.shownOpacity : 0
    transform: Translate {
        y: windows.shown ? 0 : Space.m
        Behavior on y {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }
    Behavior on opacity {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }
    RectGlide {
        target: windows
        frame: windows.frame
        rect: ({
                "x": windows.free.x + windows.gap,
                "y": windows.free.y + windows.gap,
                "w": windows.free.w - windows.gap * 2,
                "h": windows.free.h - windows.gap * 2
            })
    }

    Repeater {
        model: [[0, 0.58], [0.58, 0.42]]
        delegate: Mark {
            required property var modelData
            required property int index
            x: modelData[0] * windows.width + (index > 0 ? windows.gap / 2 : 0)
            width: modelData[1] * windows.width - windows.gap / 2
            height: windows.height
            radius: Space.smallRadius
            color: Qt.alpha(Colors.surfaceContainer, 0.62)
            border.width: Space.hairline
            border.color: Qt.alpha(index === 0 ? Colors.primary : Colors.outlineVariant, 0.55)

            // a title line and a few text lines
            Column {
                x: windows.gap
                y: windows.gap
                spacing: Math.round(windows.gap * 0.6)
                Repeater {
                    model: 4
                    delegate: Mark {
                        required property int index
                        width: (index === 0 ? 0.3 : 0.62 - index * 0.08) * windows.width * 0.5
                        height: Math.max(2, Math.round(windows.unit * 0.18))
                        color: Qt.alpha(Colors.overSurface, index === 0 ? 0.5 : 0.22)
                    }
                }
            }
        }
    }
}
