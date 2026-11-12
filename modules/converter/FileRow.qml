pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConverterModel.js" as Model

// One file of the converter: thumbnail or kind icon, name, size and format
// (or the result / the error), an arrow and the target chip, then what the
// row can do now: remove; cancel while converting; show in folder and copy
// when done. A progress line runs along the bottom while converting.
Item {
    id: root

    required property var converter
    required property string path
    readonly property var row: Model.rowByPath(root.converter.rows, root.path)
    readonly property string phase: Model.rowState(root.row)
    readonly property var target: root.row ? Model.targetOf(root.row, root.row.target) : null
    readonly property var job: root.row ? root.row.job : null
    readonly property string subtitle: root.subtitleText()
    readonly property bool working: ["pending", "queued", "running"].indexOf(root.phase) !== -1

    signal pickTarget(string path, Item anchor)

    // the full error of a failed conversion, under the row
    readonly property string errorText: root.phase === "failed" && root.job ? (root.job.error || "") : ""

    implicitHeight: Space.rowHeight + (errorLine.visible ? errorLine.implicitHeight + Space.xs : 0)
    implicitWidth: list.implicitWidth

    function subtitleText() {
        const r = root.row;
        if (!r)
            return "";
        switch (root.phase) {
        case "invalid":
            return r.error ? I18n.t("converter.error." + (r.error === "not found" ? "missing" : r.error === "a folder" ? "folder" : "unknown")) : "";
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
                    anchors.fill: parent
                    source: root.row && Model.hasThumb(root.row) ? "file://" + root.row.path : ""
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

                Chip {
                    id: chip
                    objectName: "targetChip"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.target !== null
                    focusable: true
                    text: root.row ? String(root.row.target).toUpperCase() : ""
                    trailingIcon: Model.editable(root.row) ? Icons.caretDown : ""
                    width: Math.max(implicitWidth, Space.controlXL)
                    enabled: Model.editable(root.row)
                    opacity: !enabled || root.phase === "unavailable" ? 0.38 : 1
                    onClicked: root.pickTarget(root.path, chip)
                }

                IconButton {
                    objectName: "revealButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.phase === "done"
                    size: "s"
                    icon: Icons.folderOpen
                    tooltip: I18n.t("converter.show")
                    onClicked: root.converter.reveal(root.job.output)
                }

                IconButton {
                    objectName: "copyButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.phase === "done"
                    size: "s"
                    icon: Icons.copy
                    tooltip: I18n.t("converter.copy")
                    onClicked: root.converter.copy(root.job.output)
                }

                IconButton {
                    objectName: "removeButton"
                    anchors.verticalCenter: parent.verticalCenter
                    size: "s"
                    icon: root.working ? Icons.stop : Icons.cancel
                    tooltip: I18n.t(root.working ? "converter.stop" : "converter.remove")
                    onClicked: {
                        if (root.working)
                            root.converter.cancel(root.row);
                        else
                            root.converter.remove(root.path);
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
        anchors.leftMargin: Look.rowInset + Space.controlM + Space.m
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
