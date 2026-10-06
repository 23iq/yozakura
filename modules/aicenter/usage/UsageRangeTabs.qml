pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.aicenter.common

// Today | Week | Month selector of the Usage screen.
Row {
    id: root

    property string range: "today"
    signal picked(string range)

    spacing: 4

    Repeater {
        model: ["today", "week", "month"]
        delegate: Chip {
            required property string modelData
            objectName: "usageRange_" + modelData
            implicitHeight: 26
            label: I18n.t("ai.usage.range." + modelData)
            active: root.range === modelData
            onClicked: root.picked(modelData)
        }
    }
}
