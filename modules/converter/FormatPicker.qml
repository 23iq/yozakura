pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// The target picker over the converter: the popular targets first as big
// chips, then every other one grouped by kind; the current one is marked
// (accent and a check). A target whose tool is missing is muted; choosing
// it says which tool it needs. chosen(id) or dismissed(); Esc and a click
// outside dismiss. Modal for the keyboard too: it opens with the focus on
// the current target, Tab / Shift+Tab cycle its chips, and on close the
// focus returns to the control that opened it (`returnTo`).
FocusScope {
    id: root

    property bool shown: false
    property string title: ""
    property var targets: []
    property string current: ""
    property string hint: ""
    // the control that opened the picker (focus goes back to it)
    property Item returnTo: null
    // the first and last chip: Tab wraps between them
    property Item _first: null
    property Item _last: null
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

    function open(title, targets, current, anchor) {
        root.title = title;
        root.targets = targets || [];
        root.current = current || "";
        root.hint = "";
        root.returnTo = anchor || null;
        root.shown = true;
        root.forceActiveFocus();
        root._focusCurrent();
    }

    // The chips in focus order (the visual tree: sections, then targets).
    function chips() {
        const out = [];
        const walk = item => {
            for (let i = 0; i < item.children.length; i++) {
                const c = item.children[i];
                if (String(c.objectName).indexOf("pick_") === 0)
                    out.push(c);
                else
                    walk(c);
            }
        };
        walk(card);
        return out;
    }

    function _focusCurrent() {
        const list = root.chips();
        root._first = list.length > 0 ? list[0] : null;
        root._last = list.length > 0 ? list[list.length - 1] : null;
        const cur = list.find(c => c.objectName === "pick_" + root.current) || root._first;
        if (cur)
            cur.forceActiveFocus(Qt.TabFocusReason);
    }

    // Back to the control that opened the picker (when it is still there).
    function restoreFocus(fallback) {
        const back = root.returnTo;
        root.returnTo = null;
        if (back && back.visible && back.enabled)
            back.forceActiveFocus(Qt.TabFocusReason);
        else if (fallback)
            fallback.forceActiveFocus();
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
        radius: Space.surfaceRadius
        onClicked: root.close()
    }

    Surface {
        id: card
        objectName: "pickerCard"
        anchors.centerIn: parent
        width: Math.min(parent.width - Space.xl * 2, Space.controlXL * 4)
        // the popup surface (not the window's "bg"): apart from the list
        // under the scrim, and opaque (a frosted floating box would show
        // the rows through it: nothing blurs inside the window)
        variant: "popup"
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
                                readonly property bool isCurrent: pickChip.modelData.id === root.current
                                focusable: true
                                dense: !section.modelData.popular
                                icon: pickChip.isCurrent ? Icons.check : ""
                                text: pickChip.modelData.id.toUpperCase()
                                active: pickChip.isCurrent
                                muted: !pickChip.modelData.available
                                KeyNavigation.tab: pickChip === root._last ? root._first : null
                                KeyNavigation.backtab: pickChip === root._first ? root._last : null
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
