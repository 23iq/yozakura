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
    signal changed(real value)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    activeFocusOnTab: true

    function step(dir) {
        const v = Ui.snap(value + dir * stepSize, from, to, stepSize);
        if (v !== value)
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
                    width: Math.max(implicitWidth, Type.size("body") * 3)
                    horizontalAlignment: Text.AlignHCenter
                    role: "body"
                    tabular: true
                    color: root.activeFocus ? Type.accent : Type.text
                    text: Ui.formatValue(root.value, root.unit, root.specialValues, I18n.t)
                }

                IconButton {
                    id: button
                    visible: slot.modelData !== 0
                    size: "s"
                    icon: slot.modelData < 0 ? Icons.minus : Icons.plus
                    enabled: slot.modelData < 0 ? root.value > root.from : root.value < root.to
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
