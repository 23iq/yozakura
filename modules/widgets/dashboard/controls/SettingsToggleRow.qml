import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Settings row: label + switch. `toggled(value)` fires on user changes only.
RowLayout {
    id: toggleRowRoot
    property string label: ""
    property bool checked: false
    signal toggled(bool value)

    // Track if we're updating from external binding
    property bool _updating: false

    onCheckedChanged: {
        if (!_updating && toggleSwitch.checked !== checked) {
            _updating = true;
            toggleSwitch.checked = checked;
            _updating = false;
        }
    }

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: toggleRowRoot.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(0)
        color: Colors.overBackground
        opacity: toggleRowRoot.enabled ? 1 : 0.45
        Layout.fillWidth: true
    }

    Switch {
        id: toggleSwitch
        checked: toggleRowRoot.checked
        enabled: toggleRowRoot.enabled
        opacity: toggleRowRoot.enabled ? 1 : 0.45

        onCheckedChanged: {
            if (!toggleRowRoot._updating && checked !== toggleRowRoot.checked) {
                toggleRowRoot.toggled(checked);
            }
        }

        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 20
            x: toggleSwitch.leftPadding
            y: parent.height / 2 - height / 2
            radius: height / 2
            color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.surfaceBright
            border.color: toggleSwitch.checked ? Styling.srItem("overprimary") : Colors.outline

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }

            Rectangle {
                x: toggleSwitch.checked ? parent.width - width - 2 : 2
                y: 2
                width: parent.height - 4
                height: width
                radius: width / 2
                color: toggleSwitch.checked ? Colors.background : Colors.overSurfaceVariant

                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
        background: null
    }
}
