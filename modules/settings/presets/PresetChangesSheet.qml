pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.components.kit
import "PresetStatusModel.js" as PresetStatusModel

// "Changes since <preset>": every setting whose live value differs from the
// active preset (now / preset value); a row with a settings entry opens it.
// Actions: revert, and the footer's primary action (save / save as new).
Item {
    id: root

    property bool open: false
    property var index: [] // the sidebar search index (SchemaUtil.buildSearchIndex)
    readonly property var rows: open ? PresetStatusModel.rows(PresetStatusService.status, root.index, I18n.t("common.on"), I18n.t("common.off")) : []
    readonly property string action: PresetStatusModel.primaryAction(PresetStatusService.status)
    readonly property real scrimOpacity: 0.5

    signal closed
    signal actionRequested(string id) // "save" | "saveAs" | "revert"
    signal navigate(string categoryId, string sectionId, string entryId)

    objectName: "presetChangesSheet"
    visible: open
    z: 50
    focus: open
    Keys.onEscapePressed: root.closed()
    onOpenChanged: if (open)
        card.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: root.scrimOpacity
        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Surface {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.width - Space.xxl * 2, Space.px(520))
        focus: true
        Keys.onEscapePressed: root.closed()

        MouseArea {
            anchors.fill: parent
        }

        Column {
            width: parent.width
            spacing: Space.m

            KitText {
                width: parent.width
                role: "title"
                text: I18n.t("presets.status.changes_title", PresetStatusService.active)
                wrapMode: Text.WordWrap
            }
            KitText {
                width: parent.width
                role: "secondary"
                text: I18n.tn("presets.status.changes", root.rows.length)
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(contentHeight, Space.rowHeight * 7)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                delegate: ListRow {
                    id: row
                    required property var modelData
                    width: list.width
                    title: modelData.title
                    subtitle: I18n.t("presets.status.now_preset", modelData.now, modelData.preset)
                    enabled: modelData.entry !== null
                    onClicked: {
                        const e = row.modelData.entry;
                        root.closed();
                        root.navigate(e.categoryId, e.sectionId, e.entryId);
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Space.s

                PillButton {
                    kind: "ghost"
                    text: I18n.t("common.close")
                    onClicked: root.closed()
                }
                PillButton {
                    objectName: "changesRevert"
                    visible: PresetStatusService.dirty
                    icon: "arrowCounterClockwise"
                    text: I18n.t("presets.status.revert")
                    onClicked: {
                        root.closed();
                        root.actionRequested("revert");
                    }
                }
                PillButton {
                    objectName: "changesSave"
                    visible: root.action !== ""
                    kind: "filled"
                    icon: root.action === "save" ? "check" : "plus"
                    text: root.action === "save" ? I18n.t("presets.status.save") : I18n.t("presets.status.save_as")
                    onClicked: {
                        root.closed();
                        root.actionRequested(root.action);
                    }
                }
            }
        }
    }
}
