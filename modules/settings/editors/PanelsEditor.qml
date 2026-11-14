pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import qs.modules.settings.controls
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../../bar/panels/PanelStyles.js" as PanelStyles

// bar.panels editor: the panel list (add / remove) and, for the panel
// picked here or on the Bar stage (SettingsStore.selectedPanel, the stage
// shows the whole screen), its edge, style (visual cards),
// behaviour and modules (drag & drop between the style's groups). The first
// edit of a legacy single bar turns it into bar.panels.
Item {
    id: root

    property var entry
    readonly property var panels: PanelsModel.panelsOf(Config.bar)
    // The panel being edited: the Bar stage picks it too.
    readonly property int selected: SettingsStore.selectedPanel
    readonly property int current: Math.max(0, Math.min(selected, panels.length - 1))
    readonly property var panel: panels[current] || null
    readonly property bool wide: width >= 640
    // the choices of the picked bar, one row each (labels: i18n keys)
    readonly property var edgeOptions: ["top", "bottom", "left", "right"].map(e => ({
                "value": e,
                "label": "common." + e,
                "enabled": root.panel ? PanelStyles.supportsEdge(root.panel.style, e) : true,
                "icon": {
                    "top": "arrowUp",
                    "bottom": "arrowDown",
                    "left": "arrowLeft",
                    "right": "arrowRight"
                }[e]
            }))
    readonly property var alignOptions: ["start", "center", "end"].map(a => ({
                "value": a,
                "label": "prefs.bar.panels.align." + a
            }))
    readonly property var autohideOptions: ["auto", "always", "never"].map(a => ({
                "value": a,
                "label": "prefs.bar.panels.autohide." + a
            }))
    // One width for the segmented rows (the control column of a schema
    // card): the widest of them, equal segments, their left edges lined up
    // (0 when even that does not fit beside the labels: each its own width)
    readonly property real column: {
        const w = Math.max(edgeSelector.naturalWidth, alignLine.visible ? alignSelector.naturalWidth : 0, autohideSelector.naturalWidth);
        return w + Space.l + labelMetrics.advanceWidth(I18n.t("prefs.bar.panels.autohide")) <= root.width ? w : 0;
    }
    FontMetrics {
        id: labelMetrics
        font.family: Type.family("body")
        font.pixelSize: Type.size("body")
    }

    implicitHeight: column.implicitHeight

    function commit(list) {
        SettingsStore.set("bar.panels", list);
    }
    function setField(field, value) {
        commit(PanelsModel.setField(panels, current, field, value));
    }

    // The picked bar: shown or not, then its placement and behaviour, one
    // setting a line (label left, control right, every control on the same
    // right edge as the rows of the other cards). Its shape and modules are the Shape and On
    // the bar cards (PanelShapeCards, PanelModulesCard).
    Column {
        id: column
        width: parent.width
        spacing: 0
        visible: root.panel !== null

        // the master switch first, then where it sits, how it hides, details
        Line {
            label: I18n.t("prefs.bar.panels.shown")
            ToggleControl {
                checked: root.panel ? root.panel.enabled : true
                onToggled: v => root.setField("enabled", v)
            }
        }
        Line {
            label: I18n.t("prefs.bar.panels.edge")
            SelectorControl {
                id: edgeSelector
                stretch: root.column > 0
                width: root.column > 0 ? root.column : implicitWidth
                value: root.panel ? root.panel.edge : "top"
                options: root.edgeOptions
                onSelected: v => root.setField("edge", v)
            }
        }
        Line {
            id: alignLine
            label: I18n.t("prefs.bar.panels.align")
            visible: root.panel !== null && PanelStyles.get(root.panel.style).floating
            SelectorControl {
                id: alignSelector
                stretch: root.column > 0
                width: root.column > 0 ? root.column : implicitWidth
                value: root.panel ? root.panel.align : "center"
                options: root.alignOptions
                onSelected: v => root.setField("align", v)
            }
        }
        Line {
            label: I18n.t("prefs.bar.panels.autohide")
            SelectorControl {
                id: autohideSelector
                stretch: root.column > 0
                width: root.column > 0 ? root.column : implicitWidth
                value: root.panel ? root.panel.autohide : "auto"
                options: root.autohideOptions
                onSelected: v => root.setField("autohide", v)
            }
        }
        Line {
            label: I18n.t("prefs.bar.panels.flat")
            ToggleControl {
                checked: root.panel ? root.panel.flat : false
                onToggled: v => root.setField("flat", v)
            }
        }
        Line {
            label: I18n.t("prefs.bar.panels.reserve")
            ToggleControl {
                checked: root.panel ? root.panel.reserve : true
                onToggled: v => root.setField("reserve", v)
            }
        }
    }

    // One setting: the label on the left (body role, as a SettingRow), the
    // control on the right, centred on one line; a control too wide for the
    // line goes under its label, full width.
    component Line: Item {
        id: line
        property string label
        default property alias control: holder.data
        readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
        // (a stretched selector: the column it was given)
        readonly property real controlW: line.item ? (line.item.stretch === true ? line.item.width : line.item.implicitWidth) : 0
        readonly property real controlH: line.item ? line.item.implicitHeight : 0
        readonly property bool stacked: name.implicitWidth + Space.l + line.controlW > line.width
        width: parent ? parent.width : 0
        // as tall as a settings row (Space.rowHeight), so it keeps the
        // rhythm of the cards around it
        height: line.visible ? Math.max(Space.rowHeight, (line.stacked ? name.height + Space.s + line.controlH : Math.max(name.height, line.controlH)) + Space.s * 2) : 0
        KitText {
            id: name
            x: 0
            y: line.stacked ? Space.s : Math.round((line.height - height) / 2)
            role: "body"
            text: line.label
            Accessible.ignored: true
        }
        Item {
            id: holder
            x: line.stacked ? 0 : line.width - width
            y: line.stacked ? name.y + name.height + Space.s : Math.round((line.height - height) / 2)
            width: line.stacked ? line.width : line.controlW
            height: line.controlH
        }
    }
}
