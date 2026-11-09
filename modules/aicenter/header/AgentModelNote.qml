pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit

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

    implicitHeight: Math.max(32, line.implicitHeight + 2 * Space.xs)

    RowLayout {
        id: line
        anchors.fill: parent
        // in line with the names of ModelPickerRow (past its 18 px provider icon)
        anchors.leftMargin: Space.s * 2 + 18
        anchors.rightMargin: Space.s
        spacing: Space.s
        Spinner {
            visible: root.status === "loading"
            running: visible
        }
        KitText {
            objectName: "agentModelStatus"
            role: "caption"
            Layout.fillWidth: true
            visible: !root.manual
            text: root.status === "loading" ? I18n.t("ai.loading_models") : (root.status === "error" ? I18n.t("ai.picker_models_failed") + (root.error ? ": " + root.error : "") : I18n.t("ai.picker_no_agent_models"))
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: root.status === "error" ? Colors.error : Colors.outline
        }
        Chip {
            visible: !root.manual && root.status !== "loading"
            icon: Icons.arrowsClockwise
            text: I18n.t("ai.retry_models")
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
            font.pixelSize: Type.size("caption")
            background: StyledRect {
                variant: "common"
                radius: Look.radius("small")
            }
            onAccepted: if (text.trim().length > 0)
                root.manualPicked(text.trim())
        }
    }
}
