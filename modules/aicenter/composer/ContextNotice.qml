pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/ContextMath.js" as ContextMath

// Notice at the end of the transcript when the context window fills up:
// HTTP chats offer Compact (and say when auto-compaction will kick in),
// agents only explain that they compact themselves. Dismissed per session.
StyledRect {
    id: root
    objectName: "contextNotice"

    property int used: 0
    property int window: 0
    property bool agent: false
    property bool canCompact: false
    property bool compacting: false
    property string sessionKey: ""
    property string dismissedKey: ""

    signal compactRequested

    readonly property real fraction: ContextMath.fraction(used, window)
    readonly property string level: ContextMath.level(fraction, Config.ai.context.warnAt, Config.ai.context.criticalAt)
    readonly property string message: {
        const pct = Math.round(fraction * 100);
        if (agent)
            return I18n.t("ai.context_full_agent").arg(pct);
        if (Config.ai.context.autoCompact !== false)
            return I18n.t("ai.context_full_auto").arg(pct).arg(Config.ai.context.autoCompactAt);
        return I18n.t("ai.context_full").arg(pct);
    }

    visible: Config.ai.strip.context !== false && window > 0 && level !== "ok" && dismissedKey !== sessionKey && (agent || canCompact || compacting)
    variant: level === "critical" ? "error" : "common"
    radius: Styling.radius(-4)
    implicitHeight: row.implicitHeight + 12

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 8
        Text {
            text: Icons.stack
            font.family: Icons.font
            font.pixelSize: BarLook.font(-2)
            color: root.level === "critical" ? Styling.srItem("error") : Colors.warning
        }
        Text {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.Wrap
            font.family: Config.theme.font
            font.pixelSize: BarLook.font(-3)
            color: root.level === "critical" ? Styling.srItem("error") : Colors.overSurfaceVariant
        }
        Chip {
            objectName: "noticeCompact"
            visible: !root.agent
            enabled: root.canCompact && !root.compacting
            implicitHeight: 24
            glyph: Icons.arrowsInSimple
            label: root.compacting ? I18n.t("ai.compacting") : I18n.t("ai.compact")
            onClicked: root.compactRequested()
        }
        IconButton {
            glyph: Icons.cancel
            tooltip: I18n.t("ai.dismiss")
            size: 22
            iconSize: 11
            onClicked: root.dismissedKey = root.sessionKey
        }
    }
}
