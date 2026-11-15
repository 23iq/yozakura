pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// One file of the converter: thumbnail or kind icon, name, size and format
// (or the result / the error), an arrow and the target chip (its format as
// plain text once it cannot change), then what the row can do now, in a
// fixed slot (ActionSlot) so the chips line up: remove; stop while
// converting; show in folder and copy when done. A progress line runs along
// the bottom while converting. Delete removes (stops) the row whose control
// has the keyboard focus; the focus moves on to the next control.
Item {
    id: root

    required property var converter
    required property string path
    readonly property var row: Model.rowByPath(root.converter.rows, root.path)
    readonly property string phase: Model.rowState(root.row)
    readonly property var target: root.row ? Model.targetOf(root.row, root.row.target) : null
    readonly property var job: root.row ? root.row.job : null
    readonly property string subtitle: root.subtitleText()
    readonly property bool working: Model.working(root.row)
    readonly property bool editable: Model.editable(root.row)

    signal pickTarget(string path, Item anchor)

    // the full error of a failed conversion, under the row
    readonly property string errorText: root.phase === "failed" && root.job ? root.converter.jobErrorText(root.job) : ""

    implicitHeight: Space.rowHeight + (errorLine.visible ? errorLine.implicitHeight + Space.xs : 0)
    implicitWidth: list.implicitWidth

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete) {
            root.removeOrStop(root.Window.activeFocusItem);
            event.accepted = true;
        }
    }

    // Stop a conversion under way, else remove the row. When `from` (the
    // control used) has the focus, it goes on to the next control outside
    // this row, which is about to go away.
    function removeOrStop(from) {
        if (root.working) {
            root.converter.cancel(root.row);
            return;
        }
        const next = from && from.activeFocus ? root.nextOutside(from) : null;
        root.converter.remove(root.path);
        if (next)
            next.forceActiveFocus(Qt.TabFocusReason);
    }

    function nextOutside(from) {
        let it = from;
        for (let i = 0; i < 32 && it; i++) {
            it = it.nextItemInFocusChain(true);
            if (it && !root.holds(it))
                return it;
        }
        return null;
    }

    function holds(item) {
        for (let p = item; p; p = p.parent) {
            if (p === root)
                return true;
        }
        return false;
    }

    function subtitleText() {
        const r = root.row;
        if (!r)
            return "";
        switch (root.phase) {
        case "invalid":
            return r.error ? I18n.t("converter.error." + Model.errorKey(r.code)) : "";
        case "unavailable":
            return I18n.t("converter.needs", root.target ? root.target.needs : "");
        case "failed":
            return I18n.t("converter.failed");
        case "cancelled":
            return I18n.t("converter.cancelled");
        case "done":
            return I18n.t("converter.saved", Model.baseName(root.job.output));
        case "pending":
        case "queued":
            return I18n.t("converter.waiting");
        case "running":
            return root.job.progress >= 0 ? I18n.t("converter.percent", Math.round(root.job.progress * 100)) : I18n.t("converter.converting");
        }
        return Model.formatSize(r.size) + " · " + (r.formatLabel || "");
    }

    ListRow {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Space.rowHeight
        title: root.row ? root.row.name : ""
        subtitle: root.subtitle

        leading: Component {
            Item {
                implicitWidth: Space.controlM
                implicitHeight: Space.controlM

                Art {
                    objectName: "rowArt"
                    anchors.fill: parent
                    source: root.row && Model.hasThumb(root.row) ? Model.fileUri(root.row.path) : ""
                    icon: Icons[Model.kindInfo(root.row ? root.row.kind : "").icon] || Icons.file
                }

                // done / failed badge over the corner of the art
                Icon {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: root.phase === "done" || root.phase === "failed" || root.phase === "invalid"
                    icon: root.phase === "done" ? Icons.checkCircle : Icons.warning
                    role: "body"
                    color: root.phase === "done" ? Type.accent : Type.danger
                }
            }
        }

        trailing: Component {
            Row {
                spacing: Space.s

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.target !== null
                    icon: Icons.arrowRight
                    role: "secondary"
                    tone: "muted"
                }

                // one width for every row: the chips form a column
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.target !== null
                    width: Math.max(chip.implicitWidth, Space.controlXL)
                    height: chip.implicitHeight

                    Chip {
                        id: chip
                        objectName: "targetChip"
                        anchors.fill: parent
                        visible: root.editable
                        focusable: true
                        action: true
                        // the target needs a tool that is missing: an error
                        // tint and a warning glyph (readable, not dimmed)
                        danger: root.phase === "unavailable"
                        active: root.phase === "unavailable"
                        icon: root.phase === "unavailable" ? Icons.warning : ""
                        text: root.row ? String(root.row.target).toUpperCase() : ""
                        trailingIcon: Icons.caretDown
                        onClicked: root.pickTarget(root.path, chip)
                    }

                    // converting or converted: the target, no longer a control
                    KitText {
                        objectName: "targetLabel"
                        anchors.centerIn: parent
                        visible: !root.editable
                        role: "secondary"
                        color: Type.secondary
                        text: chip.text
                    }
                }

                ActionSlot {
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        objectName: "revealButton"
                        visible: root.phase === "done"
                        size: "s"
                        focusable: true
                        icon: Icons.folderOpen
                        tooltip: I18n.t("converter.show")
                        onClicked: root.converter.reveal(root.job.output)
                    }

                    IconButton {
                        objectName: "copyButton"
                        visible: root.phase === "done"
                        size: "s"
                        focusable: true
                        icon: Icons.copy
                        tooltip: I18n.t("converter.copy")
                        onClicked: root.converter.copy(root.job.output)
                    }

                    IconButton {
                        id: removeButton
                        objectName: "removeButton"
                        size: "s"
                        focusable: true
                        icon: root.working ? Icons.stop : Icons.cancel
                        tooltip: I18n.t(root.working ? "converter.stop" : "converter.remove")
                        onClicked: root.removeOrStop(removeButton)
                    }
                }
            }
        }
    }

    KitText {
        id: errorLine
        objectName: "rowError"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: list.bottom
        anchors.leftMargin: list.textX
        anchors.rightMargin: Look.rowInset
        visible: root.errorText !== ""
        role: "caption"
        color: Type.danger
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        text: root.errorText
    }

    ProgressLine {
        objectName: "rowProgress"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: list.bottom
        anchors.leftMargin: Look.rowInset
        anchors.rightMargin: Look.rowInset
        visible: root.working
        indeterminate: !root.job || root.job.progress < 0
        value: root.job && root.job.progress > 0 ? root.job.progress : 0
    }
}
