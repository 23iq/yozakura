pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.markdown
import "../lib/Diff.js" as Diff

// Wide-mode side pane: files changed in the session (latest diff per file;
// a Codex whole-turn diff is split into its files) and the selected diff.
StyledRect {
    id: root

    property var diffs: []        // [{path, diff, key}] from AgentTimeline state
    property string selected: ""
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
    radius: Styling.radius(-2)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: Icons.gitDiff
                font.family: Icons.font
                font.pixelSize: 14
                color: Colors.primary
            }
            Text {
                text: I18n.t("ai.changes")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.weight: Font.DemiBold
                color: Colors.overSurface
                Layout.fillWidth: true
            }
            Text {
                text: root.files.length > 0 ? I18n.t("ai.files_changed").replace("%1", root.files.length) : ""
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
            }
            IconButton {
                glyph: Icons.cancel
                tooltip: I18n.t("ai.close")
                onClicked: root.closeRequested()
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: root.files
                delegate: StyledRect {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: 28
                    radius: Styling.radius(-6)
                    variant: root.current && root.current.path === entry.modelData.path ? "focus" : (rowHover.hovered ? "common" : "transparent")
                    HoverHandler {
                        id: rowHover
                    }
                    TapHandler {
                        onTapped: root.selected = entry.modelData.path
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6
                        Text {
                            text: Icons.fileCode
                            font.family: Icons.font
                            font.pixelSize: 12
                            color: Colors.outline
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.modelData.path
                            elide: Text.ElideLeft
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-3)
                            color: Colors.overSurface
                        }
                        Text {
                            text: "+" + entry.modelData.added
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-4)
                            color: Colors.success
                        }
                        Text {
                            text: "−" + entry.modelData.removed
                            font.family: Config.theme.monoFont
                            font.pixelSize: Styling.monoFontSize(-4)
                            color: Colors.error
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

        Text {
            visible: root.files.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 40
            text: I18n.t("ai.no_changes")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.outline
        }
    }
}
