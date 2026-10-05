pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Settings row: label + segmented selector.
ColumnLayout {
    id: selectorRowRoot
    property string label: ""
    property var options: []  // Array of { label: "...", value: "...", icon: "..." (optional) }
    property string value: ""
    // When false, a value matching no option selects nothing (used when
    // one setting is split across several rows).
    property bool fallbackToFirst: true
    signal valueSelected(string newValue)

    function getIndexFromValue(val: string): int {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === val)
                return i;
        }
        return fallbackToFirst ? 0 : -1;
    }

    Layout.fillWidth: true
    spacing: 4

    Text {
        text: selectorRowRoot.label
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.Medium
        color: Colors.overSurfaceVariant
        visible: selectorRowRoot.label !== ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: selectorRowRoot.options

            delegate: StyledRect {
                id: optionButton
                required property var modelData
                required property int index

                readonly property bool isSelected: selectorRowRoot.getIndexFromValue(selectorRowRoot.value) === index
                property bool isHovered: false

                variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                enableShadow: true
                Layout.fillWidth: true
                height: 36
                radius: isSelected ? Styling.radius(0) / 2 : Styling.radius(0)

                Text {
                    id: optionIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionButton.modelData.icon ?? ""
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: optionButton.item
                    visible: (optionButton.modelData.icon ?? "") !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: optionButton.modelData.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.bold: true
                    color: optionButton.item
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: optionButton.isHovered = true
                    onExited: optionButton.isHovered = false

                    onClicked: selectorRowRoot.valueSelected(optionButton.modelData.value)
                }
            }
        }
    }
}
