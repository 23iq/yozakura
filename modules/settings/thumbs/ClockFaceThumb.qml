import QtQuick
import qs.modules.settings.live
import "../live/LivePatch.js" as LivePatch

// Card picture of a bar clock face (bar.moduleOptions.clock.face): your
// bar's real clock module (live/LivePanel: its weather or day, date,
// 12-hour choice and bar style) showing face `value`.
MiniScreen {
    id: root

    property var entry
    property var value: "digital"

    LivePanel {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 6)
        patch: LivePatch.only("clock")
        frame: "modules"
        overrides: ({
                "bar.moduleOptions.clock.face": String(root.value)
            })
    }
}
