import QtQuick
import QtQuick.Layouts
import qs.modules.components
import qs.modules.components.kit

// Settings row: label + clamped integer input (+ optional suffix) in the
// kit's control box.
RowLayout {
    id: root

    property string label: ""
    property int value: 0
    property int minValue: 0
    property int maxValue: 100
    property string suffix: ""

    signal valueEdited(int newValue)

    Layout.fillWidth: true
    spacing: Space.s

    KitText {
        Layout.fillWidth: true
        role: "body"
        text: root.label
    }

    StyledRect {
        id: box
        readonly property bool lit: field.activeFocus || hover.hovered
        Layout.preferredWidth: Space.controlL
        Layout.preferredHeight: Space.chip
        variant: box.lit ? "focus" : "common"
        backgroundOpacity: Look.boxedControls ? 0 : -1
        radius: Look.radius("chip", height)

        ControlBox {
            radius: box.radius
            hovered: box.lit
        }

        HoverHandler {
            id: hover
        }

        TextInput {
            id: field
            objectName: "numberField"
            anchors.fill: parent
            anchors.margins: Space.s
            font.family: Type.family("body")
            font.pixelSize: Type.size("body")
            color: Type.text
            selectionColor: Qt.rgba(Type.accent.r, Type.accent.g, Type.accent.b, 0.3)
            selectedTextColor: Type.text
            selectByMouse: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            validator: IntValidator {
                bottom: root.minValue
                top: root.maxValue
            }

            // Follow the bound value while not editing
            readonly property int configValue: root.value
            onConfigValueChanged: {
                if (!activeFocus && text !== configValue.toString())
                    text = configValue.toString();
            }
            Component.onCompleted: text = configValue.toString()

            onEditingFinished: {
                const v = parseInt(text);
                if (!isNaN(v))
                    root.valueEdited(Math.max(root.minValue, Math.min(root.maxValue, v)));
            }
        }
    }

    KitText {
        visible: root.suffix !== ""
        role: "body"
        color: Type.secondary
        text: root.suffix
    }
}
