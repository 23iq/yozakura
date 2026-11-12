pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The target picker over the converter: the popular targets first as big
// chips, then every other one grouped by kind. A target whose tool is
// missing is dimmed; choosing it says which tool it needs. chosen(id) or
// dismissed(); Esc and a click outside dismiss.
FocusScope {
    id: root

    property bool shown: false
    property string title: ""
    property var targets: []
    property string current: ""
    property string hint: ""
    readonly property var sections: Model.pickerSections(root.targets)
    readonly property var missing: {
        const tools = [];
        (root.targets || []).forEach(t => {
            if (!t.available && t.needs && tools.indexOf(t.needs) === -1)
                tools.push(t.needs);
        });
        return tools;
    }

    signal chosen(string id)
    signal dismissed

    function open(title, targets, current) {
        root.title = title;
        root.targets = targets || [];
        root.current = current || "";
        root.hint = "";
        root.shown = true;
        root.forceActiveFocus();
    }

    function pick(t) {
        if (!t.available) {
            root.hint = I18n.t("converter.needs_for", t.id.toUpperCase(), t.needs);
            return;
        }
        root.shown = false;
        root.chosen(t.id);
    }

    function close() {
        root.shown = false;
        root.dismissed();
    }

    visible: root.shown
    focus: root.shown
    Keys.onEscapePressed: root.close()

    Scrim {
        shown: root.shown
        strength: 0.35
        radius: Space.surfaceRadius
        onClicked: root.close()
    }

    Surface {
        id: card
        objectName: "pickerCard"
        anchors.centerIn: parent
        width: Math.min(parent.width - Space.xl * 2, Space.controlXL * 4)
        floating: false
        padding: Math.max(Look.surfacePadding, Space.l)

        Column {
            width: card.width - card.padding * 2
            spacing: Space.m

            KitText {
                width: parent.width
                role: "title"
                text: root.title
                elide: Text.ElideMiddle
            }

            Repeater {
                model: root.sections

                Column {
                    id: section
                    required property var modelData
                    width: parent.width
                    spacing: Space.s

                    SectionLabel {
                        width: parent.width
                        inset: 0
                        text: section.modelData.popular ? I18n.t("converter.popular") : I18n.t(Model.kindInfo(section.modelData.kind).label)
                    }

                    Flow {
                        width: parent.width
                        spacing: Space.s

                        Repeater {
                            model: section.modelData.items

                            Chip {
                                id: pickChip
                                required property var modelData
                                objectName: "pick_" + pickChip.modelData.id
                                focusable: true
                                dense: !section.modelData.popular
                                text: pickChip.modelData.id.toUpperCase()
                                active: pickChip.modelData.id === root.current
                                opacity: pickChip.modelData.available ? 1 : 0.38
                                onClicked: root.pick(pickChip.modelData)
                            }
                        }
                    }
                }
            }

            KitText {
                objectName: "pickerHint"
                width: parent.width
                visible: text !== ""
                role: "caption"
                wrapMode: Text.WordWrap
                color: root.hint !== "" ? Type.danger : Type.muted
                text: root.hint !== "" ? root.hint : (root.missing.length > 0 ? I18n.t("converter.dimmed", root.missing.join(", ")) : "")
            }
        }
    }
}
