pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Extra row under an expanded CLI agent in the picker: its model list
// loading / failed (with Retry) / empty, or (`manual`) a field to type a
// model id the agent accepts but does not list. Enter picks it.
Item {
    id: root

    property string status: ""     // loading | error | empty ("" with manual)
    property string error: ""
    property bool manual: false

    signal retryRequested
    signal manualPicked(string model)

    implicitHeight: Math.max(32, line.implicitHeight + 8)

    RowLayout {
        id: line
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 10
        spacing: 8
        Spinner {
            visible: root.status === "loading"
            running: visible
        }
        Text {
            objectName: "agentModelStatus"
            Layout.fillWidth: true
            visible: !root.manual
            text: root.status === "loading" ? I18n.t("ai.loading_models") : (root.status === "error" ? I18n.t("ai.picker_models_failed") + (root.error ? ": " + root.error : "") : I18n.t("ai.picker_no_agent_models"))
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            color: root.status === "error" ? Colors.error : Colors.outline
        }
        Chip {
            visible: !root.manual && root.status !== "loading"
            glyph: Icons.arrowsClockwise
            label: I18n.t("ai.retry_models")
            onClicked: root.retryRequested()
        }
        TextField {
            id: field
            objectName: "agentManualModel"
            Layout.fillWidth: true
            visible: root.manual
            placeholderText: I18n.t("ai.picker_manual_model")
            placeholderTextColor: Colors.outline
            color: Colors.overSurface
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            background: StyledRect {
                variant: "common"
                radius: Styling.radius(-6)
            }
            onAccepted: if (text.trim().length > 0)
                root.manualPicked(text.trim())
        }
    }
}
