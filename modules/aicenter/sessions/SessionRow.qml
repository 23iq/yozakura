pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit as Kit
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit

// One saved conversation or agent session in the history list.
StyledRect {
    id: root

    property var entry: ({})
    property bool selected: false
    property bool highlighted: false
    signal opened
    signal pinToggled
    signal removed
    signal stopped
    signal renamed(string title)
    property bool renaming: false

    // Enter or focus loss keeps a non-empty, changed title; Escape cancels.
    function finishRename(title) {
        if (!renaming)
            return;
        renaming = false;
        const t = (title || "").trim();
        if (t && t !== (entry.title || ""))
            renamed(t);
    }

    implicitHeight: 52
    radius: Look.radius("control")
    variant: selected ? "focus" : (hov.hovered || highlighted ? "common" : "transparent")

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
        enabled: !root.renaming
        onTapped: root.opened()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.s

        Icon {
            role: "secondary"
            icon: root.entry.kind === "agent" ? Icons.terminalWindow : Icons.chatTeardrop
            tone: "secondary"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Space.hairline
            RowLayout {
                Layout.fillWidth: true
                spacing: Space.s
                Loader {
                    Layout.fillWidth: true
                    active: root.renaming
                    visible: active
                    sourceComponent: renameEditor
                }
                KitText {
                    role: "secondary"
                    Layout.fillWidth: true
                    visible: !root.renaming
                    text: root.entry.title || I18n.t("ai.untitled")
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                    color: Type.text
                }
                Icon {
                    role: "caption"
                    visible: (root.entry.pending || 0) > 0
                    icon: Icons.shieldCheck + " " + root.entry.pending
                    color: Colors.warning
                }
                StatusDot {
                    visible: root.entry.status && root.entry.status !== "exited" && root.entry.status !== "idle"
                    status: root.entry.status || "idle"
                }
                KitText {
                    role: "caption"
                    visible: !root.renaming
                    text: root.ago(root.entry.updated)
                }
            }
            KitText {
                role: "caption"
                Layout.fillWidth: true
                text: root.entry.subtitle || ""
                elide: Text.ElideRight
            }
        }
        IconButton {
            icon: Icons.stop
            size: "xs"
            visible: hov.hovered && !root.renaming && ["running", "starting", "waiting"].indexOf(root.entry.status) >= 0
            tooltip: I18n.t("ai.stop")
            onClicked: root.stopped()
        }
        IconButton {
            icon: Icons.notePencil
            size: "xs"
            visible: hov.hovered && !root.renaming
            tooltip: I18n.t("ai.rename")
            onClicked: root.renaming = true
        }
        IconButton {
            icon: Icons.pin
            size: "xs"
            active: !!root.entry.pinned
            visible: !root.renaming && (hov.hovered || root.entry.pinned)
            tooltip: root.entry.pinned ? I18n.t("ai.unpin") : I18n.t("ai.pin")
            onClicked: root.pinToggled()
        }
        IconButton {
            icon: Icons.trash
            size: "xs"
            danger: true
            visible: hov.hovered && !root.renaming
            tooltip: I18n.t("ai.delete")
            onClicked: root.removed()
        }
    }
    Component {
        id: renameEditor
        Kit.InlineEdit {
            text: root.entry.title || ""
            onAccepted: root.finishRename(text)
            onActiveFocusChanged: if (!activeFocus)
                root.finishRename(text)
            Keys.onEscapePressed: root.renaming = false
        }
    }
}
