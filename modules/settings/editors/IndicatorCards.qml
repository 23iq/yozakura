import QtQuick
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles

// Active workspace indicator (workspaces.indicatorStyle) as picture cards:
// every registered style (IndicatorStyles.js) drawn by IndicatorThumb.
Item {
    id: root

    property var entry

    implicitHeight: cards.implicitHeight

    CardSelector {
        id: cards
        width: parent.width
        entry: Object.assign({}, root.entry, {
            "thumb": "IndicatorThumb"
        })
        options: IndicatorStyles.ids().map(id => ({
                    "value": id,
                    "label": "prefs.indicator." + id
                }))
        value: SettingsStore.get("workspaces.indicatorStyle") || IndicatorStyles.DEFAULT_ID
        onSelected: v => SettingsStore.set("workspaces.indicatorStyle", v)
    }
}
