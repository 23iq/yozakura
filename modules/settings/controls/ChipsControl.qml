pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../SchemaUtil.js" as SchemaUtil

// Multi-select kit Chips (the selected ones active). options: [{value, label (i18n key or plain text),
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
        spacing: Space.xs

        Repeater {
            model: root.allLabel !== "" ? [
                {
                    "value": null,
                    "label": root.allLabel,
                    "icon": "checkCircle",
                    "all": true
                }
            ].concat(root.options) : root.options

            delegate: Chip {
                id: chip
                required property var modelData
                readonly property bool on: chip.modelData.all ? root.allSelected : root.isOn(chip.modelData.value)
                readonly property string label: root.translate || chip.modelData.all ? I18n.t(chip.modelData.label) : chip.modelData.label
                icon: chip.modelData.icon ? (Icons[chip.modelData.icon] ?? "") : ""
                text: chip.modelData.hint ? chip.label + " · " + chip.modelData.hint : chip.label
                active: chip.on
                highlighted: chip.activeFocus
                activeFocusOnTab: true
                Keys.onSpacePressed: chip.clicked()
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
