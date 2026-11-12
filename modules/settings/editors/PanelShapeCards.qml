pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel

// Several bars: the shape of the bar picked beside the stage
// (SettingsStore.selectedPanel), as the strip of style pictures of the
// Shape card.
PanelStyleCards {
    id: root

    property var entry
    readonly property var panels: PanelsModel.panelsOf(Config.bar)
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, root.panels.length - 1))

    panel: root.panels[root.current] || null
    onPicked: style => SettingsStore.set("bar.panels", PanelsModel.setField(root.panels, root.current, "style", style))
}
