import QtQuick
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch
import "../../bar/workspaces/indicators/IndicatorStyles.js" as IndicatorStyles

// Card picture of the active workspace indicator (workspaces.indicatorStyle):
// your bar's real workspaces module (live/LivePanel: the shell's own
// component, your workspaces, numerals and bar style) showing style `value`.
MiniScreen {
    id: root

    property var entry
    property var value: IndicatorStyles.DEFAULT_ID

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 6)
        patch: LivePatch.only("workspaces")
        frame: "modules"
        // a picture (taken again when the bar or the look changes)
        snapshot: true
        overrides: ({
                "workspaces.indicatorStyle": String(root.value)
            })
    }
}
