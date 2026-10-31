pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.settings.store
import qs.config
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles

// Active workspace indicator picker (workspaces.indicatorStyle): one chip
// per registered style (IndicatorStyles.js), each showing a 3-slot strip
// with the real indicator component on slot 2 (strip styles draw all three).
PreviewChips {
    id: root

    property var entry

    key: "workspaces.indicatorStyle"
    ids: IndicatorStyles.ids()
    current: SettingsStore.get("workspaces.indicatorStyle") || IndicatorStyles.DEFAULT_ID
    labelPrefix: "prefs.indicator."
    namePrefix: "indicatorChip:"

    preview: Item {
        id: preview
        property string chipId
        readonly property var style: IndicatorStyles.get(preview.chipId)

        // Fake ActiveIndicator for the style component.
        QtObject {
            id: fakeIndicator
            readonly property bool vertical: false
            readonly property real width: root.slot
            readonly property real height: root.slot
            readonly property real slotSize: root.slot
            readonly property real padding: 0
            readonly property bool occupied: true
            readonly property real baseRadius: Styling.radius(0)
            readonly property int workspaceId: 2
        }

        Loader {
            x: preview.style.strip ? 0 : root.slot
            source: preview.chipId ? Qt.resolvedUrl("../../bar/workspaces/indicators/" + preview.style.component) : ""
            onLoaded: item.indicator = fakeIndicator
        }

        Row {
            visible: !preview.style.strip
            Repeater {
                model: 3
                Text {
                    required property int index
                    width: root.slot
                    height: root.slot
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: index + 1
                    font.family: Config.theme.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: index !== 1 ? Colors.overBackground : (preview.style.filled ? Styling.srItem("primary") : Colors.primary)
                }
            }
        }
    }
}
