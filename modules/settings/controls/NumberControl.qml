pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../Ui.js" as Ui

// Stepper: kit IconButtons around the value. `changed(value)` with the
// clamped new value; holding a button repeats, arrows step from the keyboard.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string unit: ""
    property var specialValues: []
    // a wider readout the steppers of a card share (SettingsSection)
    property real readoutMin: 0
    signal changed(real value)

    // the widest readout over the range (its ends, a three-digit middle
    // value, the special values' names), never under three body glyphs
    readonly property real readoutWidth: {
        const samples = [root.from, root.to, root.value].concat((root.specialValues || []).map(s => s.value));
        let w = Math.max(Type.size("body") * 3, root.readoutMin);
        for (const v of samples)
            if (v !== undefined && isFinite(v))
                w = Math.max(w, widest.advanceWidth(Ui.formatValue(v, root.unit, root.specialValues, I18n.t)));
        return Math.ceil(w);
    }
    FontMetrics {
        id: widest
        font.family: Type.family("body")
        font.pixelSize: Type.size("body")
        font.features: ({
                "tnum": 1
            })
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    activeFocusOnTab: true

    function step(dir) {
        const v = Ui.stepValue(value, dir, from, to, stepSize, specialValues);
        if (Math.abs(v - value) > 1e-9)
            changed(v);
    }

    Keys.onLeftPressed: step(-1)
    Keys.onDownPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onUpPressed: step(1)

    Row {
        id: row
        spacing: Space.xs

        Repeater {
            model: [-1, 0, 1]

            delegate: Item {
                id: slot
                required property int modelData
                width: slot.modelData === 0 ? readout.width : button.width
                height: button.height

                KitText {
                    id: readout
                    visible: slot.modelData === 0
                    anchors.centerIn: parent
                    // as wide as the widest value it can show (tabular
                    // digits): the - / + buttons of the steppers of a card
                    // line up row to row whatever the value
                    width: Math.max(implicitWidth, root.readoutWidth)
                    horizontalAlignment: Text.AlignHCenter
                    role: "body"
                    tabular: true
                    color: root.activeFocus ? Type.accent : Type.text
                    text: Ui.formatValue(root.value, root.unit, root.specialValues, I18n.t)
                }

                IconButton {
                    id: button
                    accessibleName: I18n.t(slot.modelData < 0 ? "a11y.decrease" : "a11y.increase")
                    visible: slot.modelData !== 0
                    size: "s"
                    icon: slot.modelData < 0 ? Icons.minus : Icons.plus
                    enabled: Math.abs(Ui.stepValue(root.value, slot.modelData, root.from, root.to, root.stepSize, root.specialValues) - root.value) > 1e-9
                    onClicked: {
                        root.forceActiveFocus();
                        root.step(slot.modelData);
                    }

                    // Hold to repeat (after a press-and-hold delay).
                    Timer {
                        interval: 450
                        running: button.pressed && button.enabled
                        onTriggered: ticker.start()
                    }
                    Timer {
                        id: ticker
                        interval: 70
                        repeat: true
                        onTriggered: button.pressed && button.enabled ? root.step(slot.modelData) : stop()
                    }
                }
            }
        }
    }
}
