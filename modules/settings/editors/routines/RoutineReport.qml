pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "../../../../config/KeybindActions.js" as KeybindActions
import "../../../routines/RoutineModel.js" as RoutineModel
import qs.modules.components.kit

// Result of a test run: a summary line and one line per step
// (✓ ok, ✕ failed with its error, – skipped).
StyledRect {
    id: root

    property var report: null
    // The steps that ran: their sentences replace the backend's English labels.
    property var steps: []
    readonly property var summary: RoutineModel.reportSummary(report)

    function labelOf(res: var): string {
        const step = root.steps[res.index];
        const s = step ? RoutineModel.stepSummary(step, RoutinesService.tools, key => I18n.has(key) ? I18n.t(key) : "", id => I18n.t(KeybindActions.labelKey(id)), res.label) : "";
        return s !== "" ? s : res.label;
    }

    objectName: "routineReport"
    visible: report !== null
    variant: summary.ok ? "common" : "error"
    radius: Look.radius("control")
    implicitHeight: col.implicitHeight + 16

    ColumnLayout {
        id: col
        x: 10
        y: 8
        width: parent.width - 20
        spacing: Space.xs

        KitText {
            role: "secondary"
            Layout.fillWidth: true
            text: root.summary.ok ? I18n.t("routines.report_ok", root.summary.done, root.summary.total) : I18n.t("routines.report_failed", root.summary.done, root.summary.total)
            font.weight: Font.DemiBold
            color: root.item
        }
        Repeater {
            model: root.report ? root.report.steps : []
            delegate: RowLayout {
                id: line
                required property var modelData
                Layout.fillWidth: true
                spacing: Space.s
                Icon {
                    role: "caption"
                    icon: line.modelData.status === "ok" ? Icons.accept : (line.modelData.status === "failed" ? Icons.cancel : Icons.minus)
                    color: root.item
                    opacity: line.modelData.status === "skipped" ? 0.5 : 1
                }
                KitText {
                    role: "caption"
                    Layout.fillWidth: true
                    text: (line.modelData.index + 1) + ". " + root.labelOf(line.modelData) + (line.modelData.error ? " — " + line.modelData.error : "")
                    wrapMode: Text.WordWrap
                    color: root.item
                    opacity: line.modelData.status === "skipped" ? 0.5 : 0.9
                }
            }
        }
    }
}
