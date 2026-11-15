import QtQuick
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals

// Card picture of a numeral system (workspaces.numeralStyle): your bar's
// real workspaces module (live/LivePanel) written in system `value`, with
// its numbers shown (your indicator style, your workspaces).
MiniScreen {
    id: root

    property var entry
    property var value: WorkspaceNumerals.DEFAULT_ID

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 6)
        patch: LivePatch.only("workspaces")
        frame: "modules"
        overrides: ({
                "workspaces.numeralStyle": String(root.value),
                "workspaces.showNumbers": true
            })
    }
}
