pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Session strip in agent mode: agent, project folder, status, YOLO, stop.
RowLayout {
    id: root

    property var session: null          // meta from AgentSessions.sessions
    readonly property string status: session ? session.status : "idle"
    readonly property bool running: status === "running" || status === "starting" || status === "waiting"
    readonly property string home: Quickshell.env("HOME")

    spacing: 6

    function shortPath(p) {
        if (!p)
            return "";
        return p.indexOf(home) === 0 ? "~" + p.substring(home.length) : p;
    }

    function agentLabel(id) {
        const a = Ai.agents ? Ai.agents.agents.find(x => x.id === id) : null;
        return a ? a.label : id;
    }

    StatusDot {
        status: root.status
        Layout.leftMargin: 4
    }
    Text {
        text: root.session ? (root.session.model || root.agentLabel(root.session.agent)) : ""
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-1)
        font.weight: Font.DemiBold
        color: Colors.overSurface
    }
    Chip {
        glyph: Icons.folderOpen
        label: root.session ? root.shortPath(root.session.cwd) : ""
        mono: true
        maxLabelWidth: 200
        onClicked: if (root.session)
            Qt.openUrlExternally("file://" + root.session.cwd)
    }
    Item {
        Layout.fillWidth: true
    }
    Text {
        visible: root.session !== null
        text: I18n.t("ai.status_" + root.status)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        color: root.status === "waiting" ? Colors.warning : Colors.outline
    }
    IconButton {
        visible: root.running
        glyph: Icons.stopCircle
        tooltip: I18n.t("ai.stop") + " (Ctrl+.)"
        danger: true
        onClicked: Ai.stopSession("agent", root.session.id)
    }
}
