pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// The instrument face of a LevelSlider (Look.levelControl "knob"): a Knob
// showing the level with the icon on its cap, then an inset well holding an
// LED ladder lit up to the level (the live meter as a ghost) and the value
// as a readout (segment digits where Look.readout says so). Display only:
// the LevelSlider underneath owns press, drag, wheel and keys.
Item {
    id: root

    // The LevelSlider this face draws.
    required property var slider
    readonly property real cap: root.height
    readonly property real gap: Space.xs
    readonly property bool segment: Look.readout === "segment"
    readonly property string digits: String(root.slider.valueText).replace(/%$/, "")
    readonly property real ledW: Math.max(3, Math.round(root.height * 0.13))
    readonly property real ledGap: Math.max(2, Math.round(root.ledW * 0.6))
    readonly property real ledH: Math.round(root.height * 0.32)
    readonly property color litColor: root.slider.dimmed ? Type.muted : Type.progress

    Knob {
        objectName: "levelKnob"
        x: root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: root.cap - root.gap * 2
        height: width
        interactive: false
        value: root.slider.shown
        highlighted: root.slider.hovered
        color: root.litColor

        Text {
            text: root.slider.icon
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: root.slider.dimmed ? Type.muted : Type.text
        }
    }

    Well {
        id: well
        objectName: "levelWell"
        x: root.cap
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - root.cap - root.slider.moreW - root.gap)
        height: root.height - root.gap * 2 - Space.xs

        readonly property real readoutW: root.slider.showValue ? readout.width + Space.m : 0
        readonly property int count: Math.max(4, Math.floor((well.width - Space.s * 2 - well.readoutW + root.ledGap) / (root.ledW + root.ledGap)))

        Row {
            objectName: "levelLadder"
            x: Space.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.ledGap

            Repeater {
                model: well.count

                Rectangle {
                    id: led
                    required property int index
                    readonly property real at: (led.index + 1) / well.count
                    readonly property bool lit: led.at <= root.slider.shown + 0.5 / well.count
                    readonly property bool metered: led.at <= root.slider.level + 0.5 / well.count
                    width: root.ledW
                    height: root.ledH
                    radius: Math.min(Space.smallRadius, width / 2)
                    color: led.lit ? root.litColor : (led.metered ? Qt.alpha(root.litColor, 0.4) : Type.track)
                }
            }
        }

        Item {
            id: readout
            objectName: "levelReadout"
            visible: root.slider.showValue
            anchors.right: parent.right
            anchors.rightMargin: Space.s
            anchors.verticalCenter: parent.verticalCenter
            width: root.segment ? digitsItem.width : textItem.width
            height: parent.height

            SegmentDigits {
                id: digitsItem
                visible: root.segment
                anchors.verticalCenter: parent.verticalCenter
                text: ("   " + root.digits).slice(-Math.max(3, root.digits.length))
                digitHeight: Math.round(well.height * 0.5)
                color: root.slider.dimmed ? Type.muted : Type.text
            }

            KitText {
                id: textItem
                visible: !root.segment
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                tabular: true
                font.weight: Font.DemiBold
                text: root.slider.valueText
            }
        }
    }
}
