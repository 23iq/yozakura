pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../Macros.js" as Macros

// A macro slider (Macros.js): one step per point, the level name (or
// "Custom" while a key sits off every point) at the end, the two ends named
// below. Moving it writes the point's keys through SettingsStore, staged
// like any other edit (Discard undoes it).
ColumnLayout {
    id: root

    property var entry
    readonly property var macro: Macros.byId(entry ? entry.macro : "")
    // The live config the level is read from. A glass amount that follows
    // the preset (-1) reads as the preset's own amount.
    readonly property var ctx: ({
            "compositor": YozdService.compositorName,
            "get": k => SettingsStore.get(k),
            "effective": () => Glass.reference
        })
    readonly property int level: macro ? Macros.level(macro, ctx) : -1
    readonly property int position: macro ? Macros.nearest(macro, ctx) : 0
    readonly property var names: macro ? macro.points.map(p => I18n.t(p.label)).concat(I18n.t("prefs.macro.custom")) : []

    objectName: "macro:" + (entry ? entry.macro : "")
    spacing: Space.xs

    function moveTo(index) {
        if (!root.macro)
            return;
        Macros.writes(root.macro, index, root.ctx).forEach(w => SettingsStore.set(w.key, w.value));
    }

    // The longest level name of every macro: all rows keep one track width.
    TextMetrics {
        id: widest
        font.family: Type.family("secondary")
        font.pixelSize: Type.size("secondary")
        text: Macros.MACROS.reduce((all, m) => all.concat(m.points.map(p => I18n.t(p.label))), [I18n.t("prefs.macro.custom")]).reduce((a, b) => b.length > a.length ? b : a, "")
    }

    SliderControl {
        objectName: "macroSlider"
        Layout.fillWidth: true
        from: 0
        to: root.macro ? root.macro.points.length - 1 : 1
        stepSize: 1
        value: root.position
        valueLabel: root.level >= 0 ? root.names[root.level] : I18n.t("prefs.macro.custom")
        valueWidth: Math.ceil(widest.advanceWidth) + Space.xs
        onMoved: v => root.moveTo(Math.round(v))
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Math.ceil(widest.advanceWidth) + Space.xs + Space.m
        KitText {
            role: "caption"
            color: Type.muted
            text: root.macro ? I18n.t(root.macro.low) : ""
        }
        Item {
            Layout.fillWidth: true
        }
        KitText {
            role: "caption"
            color: Type.muted
            text: root.macro ? I18n.t(root.macro.high) : ""
        }
    }
}
