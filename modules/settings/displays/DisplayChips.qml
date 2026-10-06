pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import "DisplayFormat.js" as DisplayFormat

// Single-choice chips: options [{value, label, max}]. The option flagged
// `max` carries an accent glyph (`accentIcon`): the highest refresh rate, the
// suggested scale. The lit chip is the one matching `value`.
Flow {
    id: root

    property var options: []
    property var value: 0
    property string accentIcon: "lightning"
    signal selected(var value)

    spacing: 8

    Repeater {
        model: root.options

        delegate: Item {
            id: chip
            required property var modelData
            readonly property bool on: DisplayFormat.sameNumber(chip.modelData.value, root.value)

            width: chipRow.implicitWidth + 28
            height: 34
            activeFocusOnTab: true
            Keys.onReturnPressed: root.selected(chip.modelData.value)
            Keys.onSpacePressed: root.selected(chip.modelData.value)
            Accessible.role: Accessible.RadioButton
            Accessible.checked: chip.on
            Accessible.name: label.text

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: chip.on ? Ui.alpha(Colors.primary, area.containsMouse ? 0.34 : 0.26) : Ui.alpha(Colors.overBackground, area.containsMouse ? 0.1 : 0.05)
                border.width: chip.activeFocus ? 2 : 1
                border.color: chip.on ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!chip.modelData.max
                    text: Icons[root.accentIcon] ?? ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.tertiary
                }
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                    color: chip.on ? Colors.overBackground : Colors.overSurfaceVariant
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    chip.forceActiveFocus();
                    root.selected(chip.modelData.value);
                }
            }
        }
    }
}
