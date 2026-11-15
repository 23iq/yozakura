pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.services
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel

// Several bars: what is on the bar picked beside the stage
// (SettingsStore.selectedPanel), the On the bar card's editor.
ModuleGroupsEditor {
    id: root

    property var entry
    readonly property var panels: PanelsModel.panelsOf(Config.bar)
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, root.panels.length - 1))
    readonly property var panel: root.panels[root.current] || null

    layout: root.panel ? root.panel.groups : ({})
    available: root.panel ? PanelsModel.unused(root.panel) : []
    addGroup: "end"
    groups: root.panel ? PanelsModel.groupsOf(root.panel).map(g => ({
                "id": g,
                "icon": PanelsModel.GROUP_ICONS[g],
                "title": I18n.t(PanelsModel.GROUP_TITLES[g]),
                "hint": g === "drawer" ? I18n.t("prefs.bar.group.drawer.hint") : (g.indexOf("gap") === 0 ? I18n.t("prefs.bar.group.gap.hint") : "")
            })) : []
    onMoveRequested: (moduleId, group, index) => SettingsStore.transaction(root.entry ? root.entry.label : "", () => SettingsStore.set("bar.panels", PanelsModel.moveModule(root.panels, root.current, moduleId, group, index)))
}
