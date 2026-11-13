pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of the dashboard's home view (layout.dashboard.home): the
// stage (a big tinted player beside two small blocks over a metrics line),
// the composed overview (two even columns) or the widget grid (a bento of
// tiles).
MiniScreen {
    id: root

    property var entry
    property var value: "stage"
    readonly property real gap: root.u * 1.6
    // [x, y, w, h] in hundredths of the panel, per view
    readonly property var blocks: ({
            "stage": [[0, 0, 58, 82], [61, 0, 39, 40], [61, 43, 39, 39], [0, 88, 100, 12]],
            "composed": [[0, 0, 48, 36], [0, 40, 48, 60], [52, 0, 48, 28], [52, 32, 48, 36], [52, 72, 48, 28]],
            "bento": [[0, 0, 23, 100], [26, 0, 48, 30], [26, 34, 23, 66], [51, 34, 23, 66], [77, 0, 23, 100]]
        })

    Mark {
        id: panel
        x: root.width * 0.12
        y: root.height * 0.1
        width: root.width * 0.76
        height: root.height * 0.64
        radius: root.u * 4
        color: Qt.alpha(Colors.background, 0.92)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.8)

        Item {
            id: area
            x: root.u * 3
            y: root.u * 3
            width: panel.width - root.u * 6
            height: panel.height - root.u * 6
            Repeater {
                model: root.blocks[root.value] || []
                delegate: Mark {
                    required property var modelData
                    required property int index
                    x: area.width * modelData[0] / 100
                    y: area.height * modelData[1] / 100
                    width: area.width * modelData[2] / 100
                    height: area.height * modelData[3] / 100
                    radius: root.u * 2
                    color: root.value === "stage" && index === 0 ? Qt.alpha(Type.accent, 0.45) : Look.raisedFill(false)
                }
            }
        }
    }
}
