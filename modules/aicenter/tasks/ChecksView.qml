pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Check runs of a task run: one row per attempt (command, result, exit
// code, duration) and the output tail of the selected one.
ColumnLayout {
    id: root
    objectName: "checksView"

    property var run: null
    property int maxAttempts: 0
    property int selectedIndex: -1
    readonly property var checks: root.run && root.run.checks ? root.run.checks : []
    readonly property var current: root.checks.length === 0 ? null : root.checks[root.selectedIndex >= 0 && root.selectedIndex < root.checks.length ? root.selectedIndex : root.checks.length - 1]

    spacing: BarLook.gap

    AiText {
        role: "caption"
        Layout.fillWidth: true
        text: root.run ? I18n.t("ai.tasks.attempts_of").replace("%1", root.run.attempts || 0).replace("%2", root.maxAttempts || "–") : ""
    }

    Repeater {
        model: root.checks
        delegate: StyledRect {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + 2 * Space.s
            radius: Look.radius("control")
            variant: root.current === row.modelData ? "focus" : (hover.hovered ? "common" : "pane")
            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.selectedIndex = row.index
            }
            RowLayout {
                id: line
                anchors.fill: parent
                anchors.leftMargin: Space.s
                anchors.rightMargin: Space.s
                spacing: Space.s
                Icon {
                    role: "secondary"
                    size: BarLook.size("secondary")
                    color: Colors[row.modelData.status === "pass" ? "success" : (row.modelData.status === "skipped" ? "outline" : "error")] ?? Type.text
                    icon: row.modelData.status === "pass" ? Icons.checkCircle : (row.modelData.status === "skipped" ? Icons.minusCircle : (row.modelData.status === "timeout" ? Icons.hourglass : Icons.xCircle))
                }
                AiText {
                    role: "caption"
                    color: Type.text
                    Layout.fillWidth: true
                    text: row.modelData.command || I18n.t("ai.tasks.no_check")
                    mono: true
                }
                AiText {
                    role: "caption"
                    text: I18n.t("ai.tasks.check." + (row.modelData.status || "skipped")) + (row.modelData.exitCode ? " · " + row.modelData.exitCode : "")
                }
                AiText {
                    role: "caption"
                    text: Math.round((row.modelData.durationMs || 0) / 100) / 10 + "s"
                }
            }
        }
    }

    AiText {
        role: "secondary"
        color: Type.muted
        visible: root.checks.length === 0
        Layout.fillWidth: true
        Layout.topMargin: BarLook.gap
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("ai.tasks.no_checks")
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.current !== null && !!root.current.outputTail
        radius: Look.radius("control")
        variant: "internalbg"
        ScrollView {
            anchors.fill: parent
            anchors.margins: Space.s
            TextArea {
                objectName: "checkOutput"
                readOnly: true
                selectByMouse: true
                wrapMode: TextArea.WrapAnywhere
                text: root.current ? root.current.outputTail || "" : ""
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.monoSize("caption")
                color: Colors.overSurface
                background: null
            }
        }
    }
}
