pragma ComponentBehavior: Bound
import QtQuick
import "ClockText.js" as ClockText

// 夜桜 Yozakura: stacked mincho digits "21 時 47 分" hanging from the screen
// edge (behind the subject), a vertical kanji date column, a hairline and a
// 夜桜 seal (in front). Geometry: ClockStyleRegistry.yozakuraLayout().
ClockStyle {
    id: root

    readonly property var m: layout
    readonly property string medium: minchoMedium.name
    readonly property color sealFill: accent
    readonly property color sealInk: overInk

    FontLoader {
        id: minchoMedium
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-Medium.subset.ttf")
    }
    FontLoader {
        id: minchoRegular
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-Regular.subset.ttf")
    }
    FontLoader {
        id: minchoBold
        source: Qt.resolvedUrl("../../../assets/fonts/clock/ShipporiMinchoB1-ExtraBold.subset.ttf")
    }

    // Digits and the small 時/分/午後 units.
    component Digits: CssLine {
        anchors.horizontalCenter: parent.horizontalCenter
        family: root.medium
        weight: minchoMedium.font.weight
        size: root.m.digitSize
        tracking: root.m.digitTracking
        lineHeight: root.m.digitLine * root.m.digitSize
        color: root.ink
        colorDuration: root.animDuration
    }
    component Unit: CssLine {
        anchors.horizontalCenter: parent.horizontalCenter
        family: root.medium
        weight: minchoMedium.font.weight
        size: root.m.unitSize
        color: root.accent
        colorDuration: root.animDuration
    }
    component Gap: Item {
        width: 1
    }

    Row {
        id: row
        visible: root.m !== null && minchoMedium.status === FontLoader.Ready
        x: Math.round(root.side === "left" ? root.m.anchorX : root.m.anchorX - width)
        y: Math.round(root.m.top)
        spacing: root.m.gap
        layoutDirection: root.side === "left" ? Qt.LeftToRight : Qt.RightToLeft

        // Time: behind the subject.
        Column {
            id: timeColumn
            opacity: root.isBehind ? 1 : 0
            layer.enabled: root.isBehind
            layer.effect: ClockHalo {
                radius: 50 * root.m.u
                drop: 8 * root.m.u
                shadowColor: root.halo
                shadowOpacity: root.haloOpacity
            }

            Unit {
                visible: root.use12h
                text: ClockText.kanjiMeridiem(root.now)
            }
            Gap {
                visible: root.use12h
                height: root.m.unitGapAbove
            }
            Digits {
                text: ClockText.hours(root.now, root.use12h)
            }
            Gap {
                height: root.m.unitGapAbove
            }
            Unit {
                text: "時"
            }
            Gap {
                height: root.m.unitGapBelow
            }
            Digits {
                text: ClockText.minutes(root.now)
            }
            Gap {
                height: root.m.unitGapAbove
            }
            Unit {
                text: "分"
            }
            Gap {
                height: root.m.unitGapBelow
            }
        }

        // Date column + seal: in front of the subject.
        Column {
            id: dateColumn
            opacity: root.isFront ? 1 : 0
            topPadding: root.m.columnPadTop
            spacing: root.m.columnGap
            layer.enabled: root.isFront
            layer.effect: ClockHalo {
                radius: 24 * root.m.u
                drop: 2 * root.m.u
                shadowColor: root.halo
                shadowOpacity: root.light ? 0.35 : 0.55
            }

            VerticalText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockText.kanjiDate(root.now)
                family: root.medium
                weight: minchoMedium.font.weight
                size: root.m.dateSize
                tracking: root.m.dateTracking
                color: root.ink
                colorDuration: root.animDuration
            }
            VerticalText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ClockText.kanjiWeekday(root.now)
                family: minchoRegular.name
                weight: minchoRegular.font.weight
                size: root.m.weekdaySize
                tracking: root.m.weekdayTracking
                color: root.inkSoft
                colorDuration: root.animDuration
            }
            // Hairline.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.m.ruleWidth
                height: root.m.ruleHeight
                color: root.inkSoft
                opacity: 0.5
            }
            // 夜桜 seal.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: sealText.width + 2 * root.m.sealPadX
                height: sealText.height + 2 * root.m.sealPadY
                radius: root.m.sealRadius
                color: root.sealFill

                VerticalText {
                    id: sealText
                    anchors.centerIn: parent
                    text: "夜桜"
                    family: minchoBold.name
                    weight: minchoBold.font.weight
                    size: root.m.sealSize
                    tracking: root.m.sealTracking
                    lineWidth: 1
                    color: root.sealInk
                    colorDuration: root.animDuration
                }
            }
        }
    }
}
