pragma ComponentBehavior: Bound
import QtQuick
import "ClockText.js" as ClockText

// Poster: condensed League Gothic hours over minutes filling the screen
// height on the side away from the subject (behind it), with a vertical
// Space Grotesk date line alongside (in front).
// Geometry: ClockStyleRegistry.posterLayout().
ClockStyle {
    id: root

    readonly property var m: layout

    FontLoader {
        id: gothic
        source: Qt.resolvedUrl("../../../assets/fonts/clock/LeagueGothic-Regular.ttf")
    }
    FontLoader {
        id: groteskMedium
        source: Qt.resolvedUrl("../../../assets/fonts/clock/SpaceGrotesk-Medium.otf")
    }
    FontLoader {
        id: groteskBold
        source: Qt.resolvedUrl("../../../assets/fonts/clock/SpaceGrotesk-Bold.otf")
    }

    component Numerals: CssLine {
        anchors.horizontalCenter: parent.horizontalCenter
        family: gothic.name
        size: root.m.size
        tracking: root.m.tracking
        lineHeight: root.m.line * root.m.size
        colorDuration: root.animDuration
    }
    component DatePart: Text {
        property bool strong: false
        color: strong ? root.accent : root.ink
        font.family: strong ? groteskBold.name : groteskMedium.name
        font.weight: strong ? groteskBold.font.weight : groteskMedium.font.weight
        font.pixelSize: Math.max(1, Math.round(root.m.dateSize))
        font.letterSpacing: root.m.dateTracking * root.m.dateSize
        font.capitalization: Font.AllUppercase
        renderType: Text.QtRendering

        Behavior on color {
            enabled: root.animDuration > 0
            ColorAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    // Hours over minutes: behind the subject. Padded because the glyphs
    // overflow the tight 0.79 line boxes slightly (the layer would clip).
    Item {
        id: numerals
        readonly property real pad: 0.1 * root.m.size
        x: Math.round(root.m.centerX - width / 2)
        y: Math.round(root.m.top - pad)
        width: stack.width + 2 * pad
        height: stack.height + 2 * pad
        visible: root.isBehind && gothic.status === FontLoader.Ready
        layer.enabled: visible
        layer.effect: ClockHalo {
            radius: 80 * root.m.k
            drop: 20 * root.m.k
            shadowColor: root.halo
            shadowOpacity: root.light ? 0.2 : 0.4
        }

        Column {
            id: stack
            anchors.centerIn: parent

            Numerals {
                text: ClockText.hours(root.now, root.use12h)
                color: root.ink
            }
            Numerals {
                text: ClockText.minutes(root.now)
                color: root.accent
            }
        }
    }

    // Date line, read top to bottom (CSS vertical-rl): in front.
    Item {
        id: dateLine
        visible: root.isFront && groteskMedium.status === FontLoader.Ready
        x: Math.round(root.m.dateX)
        y: Math.round(root.m.dateTop)
        width: dateRow.height
        height: dateRow.width
        layer.enabled: visible
        layer.effect: ClockHalo {
            radius: 14 * root.m.k
            drop: 2 * root.m.k
            shadowColor: root.halo
            shadowOpacity: root.light ? 0.3 : 0.55
        }

        Row {
            id: dateRow
            transform: [
                Rotation {
                    angle: 90
                },
                Translate {
                    x: dateRow.height
                }
            ]

            DatePart {
                visible: root.use12h
                strong: true
                text: ClockText.meridiem(root.now) + " "
            }
            DatePart {
                text: Qt.formatDate(root.now, "ddd") + " "
            }
            DatePart {
                strong: true
                text: Qt.formatDate(root.now, "dd")
            }
            DatePart {
                text: " " + Qt.formatDate(root.now, "MMM") + " — " + Qt.formatDate(root.now, "yyyy")
            }
        }
    }
}
