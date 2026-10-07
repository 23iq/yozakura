import QtQuick
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components.kit
import "ActivityChips.js" as Chips

// One live activity as a bar chip (ActivityChips module): a kit Ring with
// the icon or app image inside for progress (downloads, timers), the
// activity's own indicator otherwise (recording dot, privacy glyph), and
// the compact label (percent, timer) only when it fits the bar.
// `activity` null + `overflowCount` > 0 = the "+N" chip.
Item {
    id: chip

    property var activity: null
    property int overflowCount: 0
    property bool vertical: false
    // Cross size of the bar's modules and the module glyph size (BarLook)
    property real moduleSize: 32
    property real glyphSize: 16
    property color ink: Type.text
    readonly property bool hovered: hover.hovered

    readonly property bool isOverflow: chip.activity === null
    readonly property color accent: {
        if (!chip.activity)
            return chip.ink;
        const c = Colors[chip.activity.color];
        return c !== undefined ? c : Type.progress;
    }
    readonly property bool ring: !!chip.activity && chip.activity.indicator === "ring"
    readonly property real ringSize: Math.round(chip.glyphSize * 1.35)
    // Room left for the label on a vertical bar (the chip is as wide as the bar)
    readonly property real labelRoom: chip.vertical ? chip.moduleSize - Space.xs * 2 : chip.moduleSize * 3
    readonly property bool labelShown: chip.isOverflow || Chips.showLabel(chip.activity, label.implicitWidth, chip.labelRoom)

    implicitWidth: chip.vertical ? chip.moduleSize : Math.round(lead.width + (chip.labelShown ? Space.xs + label.width : 0) + Space.xs * 2)
    implicitHeight: chip.vertical ? Math.round(lead.height + (chip.labelShown ? label.height : 0) + Space.xs * 2) : chip.moduleSize

    Grid {
        id: content
        anchors.centerIn: parent
        columns: chip.vertical ? 1 : 2
        spacing: chip.vertical ? 0 : Space.xs
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Item {
            id: lead
            visible: !chip.isOverflow
            width: visible ? chip.ringSize : 0
            height: visible ? chip.ringSize : 0

            Ring {
                anchors.fill: parent
                visible: chip.ring
                value: chip.activity && chip.activity.progress > 0 ? chip.activity.progress : 0
                thickness: Math.max(2, Math.round(chip.ringSize / 9))
                color: chip.accent
            }
            IconImage {
                id: art
                anchors.centerIn: parent
                implicitSize: Math.round(chip.ringSize * 0.56)
                source: chip.ring && chip.activity ? (chip.activity.image || "") : ""
                visible: chip.ring && status === Image.Ready
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: chip.ring && !art.visible
                text: chip.activity ? (chip.activity.icon || "") : ""
                font.family: Icons.font
                font.pixelSize: Math.round(chip.ringSize * 0.52)
                color: chip.accent
            }
            ActivityIndicator {
                anchors.centerIn: parent
                visible: !chip.ring
                kind: chip.activity ? chip.activity.indicator : "glyph"
                icon: chip.activity ? chip.activity.icon : ""
                image: chip.activity ? chip.activity.image : ""
                accent: chip.accent
                size: chip.glyphSize
            }
        }

        KitText {
            id: label
            visible: chip.labelShown
            role: "caption"
            tabular: true
            color: chip.ink
            elide: Text.ElideNone
            text: chip.isOverflow ? "+" + chip.overflowCount : (chip.activity ? String(chip.activity.label || "") : "")
        }
    }

    HoverHandler {
        id: hover
    }
}
