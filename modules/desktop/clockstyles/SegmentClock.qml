pragma ComponentBehavior: Bound
import QtQuick
import "ClockText.js" as ClockText
import qs.config
import qs.modules.theme
import qs.modules.components.kit

// Segment: an LCD clock. HH:MM as seven-segment digits (kit SegmentDigits,
// unlit segments faintly visible) in one wide line high on the side,
// behind the subject; under it a tracked mono date strip in front
// ("FRI 31 OCT 2026", 12h adds AM / PM in the accent).
// Geometry: ClockStyleRegistry.segmentLayout().
ClockStyle {
    id: root

    readonly property var m: layout

    Item {
        id: numerals
        readonly property real pad: 0.12 * root.m.digit
        x: Math.round(root.m.x - pad)
        y: Math.round(root.m.top - pad)
        width: digits.width + 2 * pad
        height: digits.height + 2 * pad
        visible: root.isBehind
        layer.enabled: visible
        layer.effect: ClockHalo {
            radius: 60 * root.m.u
            drop: 14 * root.m.u
            shadowColor: root.halo
            shadowOpacity: root.light ? 0.2 : 0.4
        }

        SegmentDigits {
            id: digits
            anchors.centerIn: parent
            // 12h hours are unpadded: a blank cell keeps the width.
            text: ("  " + ClockText.hours(root.now, root.use12h)).slice(-2) + ":" + ClockText.minutes(root.now)
            digitHeight: root.m.digit
            color: root.ink
            offOpacity: 0.07
        }
    }

    Row {
        id: dateLine
        visible: root.isFront
        x: Math.round(root.m.x)
        y: Math.round(root.m.dateTop)
        spacing: root.m.dateSize * root.m.dateTracking * 2
        layer.enabled: visible
        layer.effect: ClockHalo {
            radius: 14 * root.m.u
            drop: 2 * root.m.u
            shadowColor: root.halo
            shadowOpacity: root.light ? 0.3 : 0.55
        }

        Repeater {
            model: [
                {
                    "text": root.use12h ? ClockText.meridiem(root.now) : "",
                    "strong": true
                },
                {
                    "text": Qt.formatDate(root.now, "ddd"),
                    "strong": false
                },
                {
                    "text": Qt.formatDate(root.now, "dd"),
                    "strong": true
                },
                {
                    "text": Qt.formatDate(root.now, "MMM yyyy"),
                    "strong": false
                }
            ]

            Text {
                required property var modelData
                visible: modelData.text !== ""
                text: modelData.text
                color: modelData.strong ? root.accent : root.inkSoft
                font.family: Config.theme.monoFont
                font.pixelSize: Math.max(1, Math.round(root.m.dateSize))
                font.weight: modelData.strong ? Font.DemiBold : Font.Medium
                font.letterSpacing: root.m.dateTracking * root.m.dateSize
                font.capitalization: Font.AllUppercase

                Behavior on color {
                    enabled: root.animDuration > 0
                    ColorAnimation {
                        duration: root.animDuration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }
}
