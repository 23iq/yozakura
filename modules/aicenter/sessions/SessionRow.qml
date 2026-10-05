pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// One saved conversation or agent session in the history drawer.
StyledRect {
    id: root

    property var entry: ({})
    property bool selected: false
    signal opened
    signal pinToggled
    signal removed

    implicitHeight: 52
    radius: Styling.radius(-4)
    variant: selected ? "focus" : (hov.hovered ? "common" : "transparent")

    function ago(ms) {
        if (!ms)
            return "";
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60)
            return I18n.t("ai.just_now");
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    HoverHandler {
        id: hov
    }
    TapHandler {
        onTapped: root.opened()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10

        Text {
            text: root.entry.kind === "agent" ? Icons.terminalWindow : (root.entry.mode === "shell" ? Icons.command : Icons.chatTeardrop)
            font.family: Icons.font
            font.pixelSize: 15
            color: root.entry.kind === "agent" ? Colors.tertiary : Colors.primary
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: root.entry.title || I18n.t("ai.untitled")
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Colors.overSurface
                }
                StatusDot {
                    visible: root.entry.kind === "agent" && root.entry.status !== "exited" && root.entry.status !== "idle"
                    status: root.entry.status || "idle"
                }
                Text {
                    text: root.ago(root.entry.updated)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-4)
                    color: Colors.outline
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.entry.subtitle || ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
            }
        }
        IconButton {
            glyph: Icons.pin
            size: 24
            iconSize: 12
            active: !!root.entry.pinned
            visible: hov.hovered || root.entry.pinned
            tooltip: root.entry.pinned ? I18n.t("ai.unpin") : I18n.t("ai.pin")
            onClicked: root.pinToggled()
        }
        IconButton {
            glyph: Icons.trash
            size: 24
            iconSize: 12
            danger: true
            visible: hov.hovered
            tooltip: I18n.t("ai.delete")
            onClicked: root.removed()
        }
    }
}
