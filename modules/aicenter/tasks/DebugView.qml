pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Session log of a run (tasks.debug): launch command (redacted argv),
// working directory, process state, stderr and the raw event tail.
ColumnLayout {
    id: root
    objectName: "debugView"

    property string taskId: ""
    property int run: 0
    property var info: null
    property string error: ""
    property bool loading: false

    function reload() {
        if (!root.taskId || !root.visible)
            return;
        root.loading = true;
        TasksService.debug(root.taskId, root.run, 200, (res, error) => {
            root.loading = false;
            root.info = res;
            root.error = error;
        });
    }
    function field(label, value) {
        return value ? label + "  " + value + "\n" : "";
    }
    readonly property string text: {
        const d = root.info;
        if (!d)
            return "";
        let out = root.field("agent", d.agent) + root.field("session", d.session) + root.field("agent session", d.agentSessionId) + root.field("status", d.status + (d.running ? " (running)" : "")) + root.field("cwd", d.cwd) + root.field("log", d.logPath);
        out += "\n$ " + (d.argv || []).join(" ") + "\n";
        if (d.stderr)
            out += "\n── stderr ──\n" + d.stderr + "\n";
        if (d.lastCheck)
            out += "\n── last check ──\n" + JSON.stringify(d.lastCheck, null, 2) + "\n";
        out += "\n── events ──\n" + (d.logTail || []).join("\n");
        return out;
    }

    onTaskIdChanged: reload()
    onRunChanged: reload()
    onVisibleChanged: reload()
    Component.onCompleted: reload()

    spacing: BarLook.gap

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        UiText {
            Layout.fillWidth: true
            text: root.error || (root.loading ? I18n.t("ai.tasks.loading") : I18n.t("ai.tasks.debug_hint"))
            color: root.error ? Colors.error : Colors.outline
            size: -2
            wrapMode: Text.Wrap
        }
        IconButton {
            glyph: Icons.copy
            tooltip: I18n.t("ai.copy")
            onClicked: {
                log.selectAll();
                log.copy();
                log.deselect();
            }
        }
        IconButton {
            objectName: "debugRefresh"
            glyph: Icons.arrowsClockwise
            tooltip: I18n.t("ai.tasks.refresh")
            onClicked: root.reload()
        }
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Styling.radius(-4)
        variant: "internalbg"
        ScrollView {
            anchors.fill: parent
            anchors.margins: 8
            TextArea {
                id: log
                objectName: "debugLog"
                readOnly: true
                selectByMouse: true
                wrapMode: TextArea.WrapAnywhere
                text: root.text
                font.family: Config.theme.monoFont
                font.pixelSize: BarLook.mono(-4)
                color: Colors.overSurface
                background: null
            }
        }
    }
}
