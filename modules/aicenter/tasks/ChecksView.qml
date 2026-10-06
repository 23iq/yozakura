pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
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

    UiText {
        Layout.fillWidth: true
        text: root.run ? I18n.t("ai.tasks.attempts_of").replace("%1", root.run.attempts || 0).replace("%2", root.maxAttempts || "–") : ""
        muted: true
        size: -2
    }

    Repeater {
        model: root.checks
        delegate: StyledRect {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + 12
            radius: Styling.radius(-4)
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
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Glyph {
                    text: row.modelData.status === "pass" ? Icons.checkCircle : (row.modelData.status === "skipped" ? Icons.minusCircle : (row.modelData.status === "timeout" ? Icons.hourglass : Icons.xCircle))
                    role: row.modelData.status === "pass" ? "success" : (row.modelData.status === "skipped" ? "outline" : "error")
                }
                UiText {
                    Layout.fillWidth: true
                    text: row.modelData.command || I18n.t("ai.tasks.no_check")
                    mono: true
                    size: -2
                }
                UiText {
                    text: I18n.t("ai.tasks.check." + (row.modelData.status || "skipped")) + (row.modelData.exitCode ? " · " + row.modelData.exitCode : "")
                    muted: true
                    size: -3
                }
                UiText {
                    text: Math.round((row.modelData.durationMs || 0) / 100) / 10 + "s"
                    muted: true
                    size: -3
                }
            }
        }
    }

    UiText {
        visible: root.checks.length === 0
        Layout.fillWidth: true
        Layout.topMargin: BarLook.gap
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("ai.tasks.no_checks")
        muted: true
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.current !== null && !!root.current.outputTail
        radius: Styling.radius(-4)
        variant: "internalbg"
        ScrollView {
            anchors.fill: parent
            anchors.margins: 8
            TextArea {
                objectName: "checkOutput"
                readOnly: true
                selectByMouse: true
                wrapMode: TextArea.WrapAnywhere
                text: root.current ? root.current.outputTail || "" : ""
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.mono(-3)
                color: Colors.overSurface
                background: null
            }
        }
    }
}
