pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../../routines/RoutineModel.js" as RoutineModel

// Result of a test run: a summary line and one line per step
// (✓ ok, ✕ failed with its error, – skipped).
StyledRect {
    id: root

    property var report: null
    readonly property var summary: RoutineModel.reportSummary(report)

    objectName: "routineReport"
    visible: report !== null
    variant: summary.ok ? "common" : "error"
    radius: Styling.radius(-3)
    implicitHeight: col.implicitHeight + 16

    ColumnLayout {
        id: col
        x: 10
        y: 8
        width: parent.width - 20
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: root.summary.ok ? I18n.t("routines.report_ok", root.summary.done, root.summary.total) : I18n.t("routines.report_failed", root.summary.done, root.summary.total)
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
            color: root.item
        }
        Repeater {
            model: root.report ? root.report.steps : []
            delegate: RowLayout {
                id: line
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: line.modelData.status === "ok" ? Icons.accept : (line.modelData.status === "failed" ? Icons.cancel : Icons.minus)
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: root.item
                    opacity: line.modelData.status === "skipped" ? 0.5 : 1
                }
                Text {
                    Layout.fillWidth: true
                    text: (line.modelData.index + 1) + ". " + line.modelData.label + (line.modelData.error ? " — " + line.modelData.error : "")
                    wrapMode: Text.WordWrap
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: root.item
                    opacity: line.modelData.status === "skipped" ? 0.5 : 0.9
                }
            }
        }
    }
}
