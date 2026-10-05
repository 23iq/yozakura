pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui
import "../SchemaUtil.js" as SchemaUtil

// Multi-select chips. options: [{value, label (i18n key or plain text),
// icon, hint}]; `values` is the selected array. With `allLabel` an extra
// first chip stands for the empty array ("every screen"): it is lit when
// nothing is selected and clears the selection when clicked.
Item {
    id: root

    property var options: []
    property var values: []
    property string allLabel: ""
    property bool translate: true
    signal changed(var values)

    readonly property bool allSelected: !values || values.length === 0

    function isOn(v) {
        return (root.values || []).some(x => SchemaUtil.equal(x, v));
    }

    function toggle(v) {
        root.changed(SchemaUtil.toggleValue(root.values, v, root.options));
    }

    implicitWidth: 420
    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: parent.width
        spacing: 8

        Repeater {
            model: root.allLabel !== "" ? [
                {
                    "value": null,
                    "label": root.allLabel,
                    "icon": "checkCircle",
                    "all": true
                }
            ].concat(root.options) : root.options

            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool on: chip.modelData.all ? root.allSelected : root.isOn(chip.modelData.value)
                width: chipRow.implicitWidth + 28
                height: 34
                activeFocusOnTab: true
                Keys.onSpacePressed: area.clicked(null)
                Accessible.role: Accessible.CheckBox
                Accessible.checked: chip.on
                Accessible.name: label.text

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: chip.on ? Ui.alpha(Colors.primary, area.containsMouse ? 0.32 : 0.24) : Ui.alpha(Colors.overBackground, area.containsMouse ? 0.1 : 0.05)
                    border.width: chip.activeFocus ? 2 : 1
                    border.color: chip.on ? Colors.primary : Ui.alpha(Colors.outline, 0.35)
                    Behavior on color {
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
                        visible: !!chip.modelData.icon || chip.on
                        text: chip.on ? Icons.accept : (Icons[chip.modelData.icon] ?? "")
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: chip.on ? Colors.primary : Colors.overSurfaceVariant
                    }
                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.translate || chip.modelData.all ? I18n.t(chip.modelData.label) : chip.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: chip.on ? Font.DemiBold : Font.Normal
                        color: chip.on ? Colors.overBackground : Colors.overSurfaceVariant
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!chip.modelData.hint
                        text: chip.modelData.hint ?? ""
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        chip.forceActiveFocus();
                        if (chip.modelData.all)
                            root.changed([]);
                        else
                            root.toggle(chip.modelData.value);
                    }
                }
            }
        }
    }
}
