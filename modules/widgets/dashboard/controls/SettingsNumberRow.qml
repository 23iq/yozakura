import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Settings row: label + clamped integer input (+ optional suffix).
RowLayout {
    id: numberInputRowRoot
    property string label: ""
    property int value: 0
    property int minValue: 0
    property int maxValue: 100
    property string suffix: ""
    signal valueEdited(int newValue)

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: numberInputRowRoot.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        color: Colors.overBackground
        Layout.fillWidth: true
    }

    StyledRect {
        variant: "common"
        Layout.preferredWidth: 60
        Layout.preferredHeight: 32
        radius: Styling.radius(-2)

        TextInput {
            id: numberTextInput
            anchors.fill: parent
            anchors.margins: 8
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            selectByMouse: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            validator: IntValidator {
                bottom: numberInputRowRoot.minValue
                top: numberInputRowRoot.maxValue
            }

            // Sync text when external value changes
            readonly property int configValue: numberInputRowRoot.value
            onConfigValueChanged: {
                if (!activeFocus && text !== configValue.toString()) {
                    text = configValue.toString();
                }
            }
            Component.onCompleted: text = configValue.toString()

            onEditingFinished: {
                let newVal = parseInt(text);
                if (!isNaN(newVal)) {
                    newVal = Math.max(numberInputRowRoot.minValue, Math.min(numberInputRowRoot.maxValue, newVal));
                    numberInputRowRoot.valueEdited(newVal);
                }
            }
        }
    }

    Text {
        text: numberInputRowRoot.suffix
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        color: Colors.overSurfaceVariant
        visible: numberInputRowRoot.suffix !== ""
    }
}
