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
import qs.modules.aicenter.markdown
import "../lib/Diff.js" as Diff

// Wide-mode side pane: files changed in the session (latest diff per file;
// a Codex whole-turn diff is split into its files) and the selected diff.
StyledRect {
    id: root

    property var diffs: []        // [{path, diff, key}] from AgentTimeline state
    property string selected: ""
    property bool closable: true
    signal closeRequested

    readonly property var files: {
        const byPath = {};
        const order = [];
        for (const d of diffs) {
            if (d.path) {
                if (!byPath[d.path])
                    order.push(d.path);
                byPath[d.path] = {
                    path: d.path,
                    diff: d.diff
                };
                continue;
            }
            // whole-turn diff: one entry per file inside it
            for (const f of Diff.parse(d.diff)) {
                if (!f.path)
                    continue;
                if (!byPath[f.path])
                    order.push(f.path);
                byPath[f.path] = {
                    path: f.path,
                    diff: d.diff,
                    fromTurn: true
                };
            }
        }
        return order.map(p => {
            const e = byPath[p];
            const parsed = Diff.parse(e.diff, p).filter(f => f.path === p || !e.fromTurn);
            const s = Diff.stats(parsed);
            return {
                path: p,
                diff: e.diff,
                added: s.added,
                removed: s.removed
            };
        });
    }
    readonly property var current: files.find(f => f.path === selected) || (files.length > 0 ? files[files.length - 1] : null)

    variant: "pane"
    radius: Look.radius("control")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Space.s
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            Icon {
                role: "caption"
                tone: "accent"
                icon: Icons.gitDiff
            }
            KitText {
                text: I18n.t("ai.changes")
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            KitText {
                role: "caption"
                text: root.files.length > 0 ? I18n.t("ai.files_changed").replace("%1", root.files.length) : ""
            }
            IconButton {
                size: "xs"
                visible: root.closable
                icon: Icons.cancel
                tooltip: I18n.t("ai.close")
                onClicked: root.closeRequested()
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: Space.xs / 2
            Repeater {
                model: root.files
                delegate: StyledRect {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: 28
                    radius: Look.radius("small")
                    variant: root.current && root.current.path === entry.modelData.path ? "focus" : (rowHover.hovered ? "common" : "transparent")
                    HoverHandler {
                        id: rowHover
                    }
                    TapHandler {
                        onTapped: root.selected = entry.modelData.path
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Space.s
                        anchors.rightMargin: Space.s
                        spacing: Space.s
                        Icon {
                            role: "label"
                            tone: "muted"
                            icon: Icons.fileCode
                        }
                        KitText {
                            role: "caption"
                            Layout.fillWidth: true
                            text: entry.modelData.path
                            elide: Text.ElideLeft
                            font.family: Type.monoFont
                            color: Type.text
                        }
                        KitText {
                            role: "caption"
                            text: "+" + entry.modelData.added
                            font.family: Type.monoFont
                            color: Colors.success
                        }
                        KitText {
                            role: "caption"
                            text: "−" + entry.modelData.removed
                            font.family: Type.monoFont
                            color: Type.danger
                        }
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: diffView.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            DiffView {
                id: diffView
                width: parent.width
                visible: root.current !== null
                diff: root.current ? root.current.diff : ""
                path: root.current ? root.current.path : ""
                maxRows: 2000
            }
        }

        KitText {
            role: "secondary"
            visible: root.files.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Space.xxl
            text: I18n.t("ai.no_changes")
            color: Type.muted
        }
    }
}
