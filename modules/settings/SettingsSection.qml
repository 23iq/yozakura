pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui
import "SchemaUtil.js" as SchemaUtil
import "ChangesModel.js" as ChangesModel

// One schema section as a bento card (kit Card): a heading (the section
// title) with the current value on the right when the card holds one
// setting ("Shape ... Classic"), over one SettingRow per entry that is in
// the window (SchemaUtil.inWindow: no row object exists for an
// out-of-window entry) and not shown beside the stage (`exclude`). A card
// of one picture / editor setting drops the row's own label (the heading
// names it). The card shows only while one of its rows does
// (SettingsStore.sectionShown: compositor gate, visibleWhen).
Card {
    id: sectionRoot

    required property var section
    // entry keys / ids shown elsewhere (beside the stage)
    property var exclude: []
    readonly property string sectionId: section.id
    readonly property var entries: (section.entries || []).filter(e => SchemaUtil.inWindow(e, section) && sectionRoot.exclude.indexOf(e.key || e.id) < 0)
    readonly property bool shown: sectionRoot.entries.length > 0 && SettingsStore.sectionShown(section)
    // A row card whose rows all wait (the thing is turned off): it stays and
    // says so instead of vanishing from the row.
    readonly property bool waiting: sectionRoot.fixed && sectionRoot.entries.length > 0 && !sectionRoot.shown
    // one setting: its value beside the heading, no label of its own
    readonly property var visibleEntries: sectionRoot.entries.filter(e => SettingsStore.visible(e))
    readonly property var single: sectionRoot.visibleEntries.length === 1 ? sectionRoot.visibleEntries[0] : null
    readonly property string value: {
        const e = sectionRoot.single;
        if (!e || !e.key || e.type === "toggle")
            return "";
        const v = SettingsStore.get(e.key);
        return v === undefined || v === null || typeof v === "object" || typeof v === "boolean" ? "" : ChangesModel.describe(e, v, k => I18n.t(k));
    }
    // Not built yet: the page fills its sections in a few per frame.
    property bool pending: false
    // Shown elsewhere (a fitted page puts its other sections in a sheet):
    // this copy builds no rows.
    property bool suppressed: false
    // A card of the page row: its height is set from outside; a single
    // picture / editor setting fills it, more rows scroll inside the card.
    property bool fixed: false

    function rowFor(entryId) {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (Ui.prop(r, "entryId") === entryId)
                return r;
        }
        return null;
    }

    objectName: "settingsSection:" + sectionId
    visible: (sectionRoot.shown || sectionRoot.waiting) && !sectionRoot.pending && !sectionRoot.suppressed
    padding: Look.boxPadding + Space.s
    spacing: Space.s

    Item {
        id: headerBox
        width: sectionRoot.contentWidth
        height: Math.max(heading.implicitHeight, valueText.implicitHeight)
        visible: heading.text !== ""

        KitText {
            id: heading
            objectName: "sectionHeading"
            width: parent.width - (valueText.visible ? valueText.implicitWidth + Space.m : 0)
            role: "title"
            text: sectionRoot.section.title ? I18n.t(sectionRoot.section.title) : ""
            elide: Text.ElideRight
        }
        KitText {
            id: valueText
            objectName: "sectionValue"
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            visible: sectionRoot.value !== ""
            role: "secondary"
            text: sectionRoot.value
        }
    }

    KitText {
        objectName: "sectionWaiting"
        visible: sectionRoot.waiting
        width: sectionRoot.contentWidth
        role: "secondary"
        wrapMode: Text.WordWrap
        text: I18n.t("prefs.page.card_off")
    }

    Item {
        id: rowsBox
        readonly property real room: Math.max(0, sectionRoot.height - sectionRoot.padding * 2 - (headerBox.visible ? headerBox.height + sectionRoot.spacing : 0))
        width: sectionRoot.contentWidth
        height: sectionRoot.fixed ? rowsBox.room : rowsColumn.height
        clip: sectionRoot.fixed

        Flickable {
            id: rowsFlick
            objectName: "cardScroll"
            anchors.fill: parent
            contentWidth: width
            contentHeight: rowsColumn.height
            interactive: sectionRoot.fixed && contentHeight > height + 1
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rowsColumn
                width: rowsBox.width
                spacing: 0

                Repeater {
                    id: rows
                    model: sectionRoot.pending || !sectionRoot.shown || sectionRoot.suppressed ? [] : sectionRoot.entries

                    delegate: SettingRow {
                        required property var modelData
                        required property int index
                        width: rowsColumn.width
                        entry: modelData
                        bare: sectionRoot.single !== null
                        // a single picture / editor fills the card
                        fillHeight: sectionRoot.fixed && sectionRoot.single !== null ? Math.max(0, rowsBox.room - Space.s * 2) : 0
                        previousEntry: index > 0 ? sectionRoot.entries[index - 1] : null
                    }
                }
            }
        }
        // more below: a fade at the bottom of the card
        Mark {
            visible: rowsFlick.interactive && rowsFlick.contentY < rowsFlick.contentHeight - rowsFlick.height - 1
            anchors.bottom: parent.bottom
            width: parent.width
            height: Space.xl
            radius: 0
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: Look.cardFill(false)
                }
            }
        }
    }
}
