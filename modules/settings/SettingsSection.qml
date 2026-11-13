pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui
import "SchemaUtil.js" as SchemaUtil
import "CardGate.js" as CardGate
import "RowLines.js" as RowLines

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
    // `toggle`: the key of a switch of this section drawn in the card's
    // heading (the card is the thing it turns on: Special workspaces)
    readonly property var headerToggle: section.toggle ? (section.entries || []).find(e => e.key === section.toggle) || null : null
    readonly property var entries: (section.entries || []).filter(e => SchemaUtil.inWindow(e, section) && sectionRoot.exclude.indexOf(e.key || e.id) < 0 && !(section.toggle && e.key === section.toggle))
    // A card of the page row whose rows wait on one switch: they show
    // dimmed, with one "Turn on" for the card (CardGate.js).
    readonly property var gate: CardGate.gate(sectionRoot.entries, SettingsStore.get, k => SettingsStore.entryByKey[k] || null)
    // keys of the switches shown elsewhere on the page: the card offers no
    // "Turn on" of its own for one of them (one control per key on a page);
    // its waiting rows stay dimmed and a press on one flips that switch
    property var pageKeys: []
    readonly property bool offersTurnOn: sectionRoot.gate !== null && sectionRoot.pageKeys.indexOf(sectionRoot.gate.fix.key) < 0
    readonly property bool shown: sectionRoot.entries.length > 0 && (SettingsStore.sectionShown(section) || sectionRoot.gate !== null)
    // A row card whose rows all wait (the thing is turned off): it stays and
    // says so instead of vanishing from the row.
    readonly property bool waiting: false
    // one setting: its value beside the heading, no label of its own
    readonly property var visibleEntries: sectionRoot.entries.filter(e => SettingsStore.visible(e) || (sectionRoot.gate !== null && sectionRoot.gate.ids.indexOf(e.id || e.key) >= 0))
    readonly property var single: sectionRoot.visibleEntries.length === 1 ? sectionRoot.visibleEntries[0] : null
    // A card of the page row with one picture choice among a few compact
    // rows (Island: the shape over its alignment): the pictures keep their
    // strip, in the height the other rows leave, without a label.
    readonly property var strip: {
        if (!sectionRoot.fixed || sectionRoot.single !== null)
            return null;
        const pics = sectionRoot.visibleEntries.filter(e => e.display === "cards");
        return pics.length === 1 && sectionRoot.visibleEntries.length <= 3 ? pics[0] : null;
    }
    // the rows in lines: picture choices that follow each other share one
    // when their pictures fit it, short rows stand beside pictures that
    // leave room (RowLines.js); a card of the page row keeps one row a line.
    // Set only when the grouping changes (a resize that keeps it rebuilds
    // no row).
    readonly property real pictureMax: Space.px(190)
    property var lines: sectionRoot.groupLines()
    function groupLines() {
        // (no section yet while the card is being created)
        const entries = sectionRoot.entries || [];
        return sectionRoot.fixed ? entries.map((e, i) => ({
                    "rows": [i],
                    "side": []
                })) : RowLines.layout(entries, sectionRoot.contentWidth, Space.m, Space.px(96), sectionRoot.pictureMax, Space.px(260), Space.px(680));
    }
    function regroup() {
        const next = sectionRoot.groupLines();
        if (JSON.stringify(next) !== JSON.stringify(sectionRoot.lines))
            sectionRoot.lines = next;
    }
    onEntriesChanged: sectionRoot.regroup()
    onContentWidthChanged: sectionRoot.regroup()
    onFixedChanged: sectionRoot.regroup()
    readonly property real stripHeight: sectionRoot.strip ? Math.max(0, rowsBox.room - (sectionRoot.visibleEntries.length - 1) * (Space.rowHeight + Space.xs) - Space.s * 2) : 0
    // Not built yet: the page fills its sections in a few per frame.
    property bool pending: false
    // Shown elsewhere (a fitted page puts its other sections in a sheet):
    // this copy builds no rows.
    property bool suppressed: false
    // A card of the page row: its height is set from outside; a single
    // picture / editor setting fills it, more rows scroll inside the card.
    property bool fixed: false

    function rowFor(entryId) {
        if (sectionRoot.headerToggle && entryId === sectionRoot.headerToggle.key)
            return headSwitch;
        for (let i = 0; i < rows.count; i++) {
            const line = rows.itemAt(i);
            const all = line ? line.items() : [];
            for (const r of all)
                if (Ui.prop(r, "entryId") === entryId)
                    return r;
        }
        return null;
    }

    objectName: "settingsSection:" + sectionId
    // reached from a click on the stage: a brief accent wash
    background: Mark {
        objectName: "sectionFlash"
        anchors.fill: parent
        radius: Look.radius("surface", height)
        color: Type.accent
        opacity: SettingsStore.highlightedSection !== "" && SettingsStore.highlightedSection === sectionRoot.sectionId ? 0.16 : 0
        Behavior on opacity {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }
    visible: (sectionRoot.shown || sectionRoot.waiting) && !sectionRoot.pending && !sectionRoot.suppressed
    padding: Look.boxPadding + Space.s
    spacing: Space.s

    Item {
        id: headerBox
        width: sectionRoot.contentWidth
        height: heading.implicitHeight
        visible: heading.text !== ""

        KitText {
            id: heading
            objectName: "sectionHeading"
            // (no value summary: the card's own control shows the value)
            width: parent.width - (gateChip.visible ? gateChip.width + Space.m : 0) - (headSwitch.visible ? headSwitch.width + Space.m : 0)
            role: "title"
            text: sectionRoot.section.title ? I18n.t(sectionRoot.section.title) : ""
            elide: Text.ElideRight
        }
        Switch {
            id: headSwitch
            objectName: sectionRoot.headerToggle ? "settingRow:" + sectionRoot.headerToggle.key : ""
            visible: sectionRoot.headerToggle !== null
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            checked: sectionRoot.headerToggle ? SettingsStore.get(sectionRoot.headerToggle.key) === true : false
            Accessible.name: sectionRoot.headerToggle ? I18n.t(sectionRoot.headerToggle.label) : ""
            onToggled: v => SettingsStore.set(sectionRoot.headerToggle.key, v)
        }
        // the card's rows wait on one switch: turn it on from here
        Chip {
            id: gateChip
            objectName: "sectionTurnOn"
            visible: sectionRoot.offersTurnOn
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            dense: true
            primary: true
            icon: Icons.power
            text: sectionRoot.gate ? I18n.t(sectionRoot.gate.fix.on ? "prefs.disabled.turn_on" : "prefs.disabled.turn_off") : ""
            Accessible.name: sectionRoot.gate ? I18n.t(sectionRoot.gate.fix.entry.label) : ""
            onClicked: if (sectionRoot.gate)
                SettingsStore.set(sectionRoot.gate.fix.key, sectionRoot.gate.fix.value)
        }
    }

    KitText {
        objectName: "sectionWaiting"
        visible: sectionRoot.waiting && sectionRoot.gate === null
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

                Component {
                    id: rowDelegate

                    SettingRow {
                        id: lineItem
                        // the entry's index in the card
                        required property var modelData
                        readonly property var e: sectionRoot.entries[lineItem.modelData] || ({})
                        readonly property string eid: lineItem.e.id || lineItem.e.key || ""
                        width: lineItem.parent && lineItem.parent.rowWidth ? lineItem.parent.rowWidth(lineItem.modelData) : rowsColumn.width
                        entry: lineItem.e
                        // the card's heading already names it: no second label
                        bare: sectionRoot.single !== null || (sectionRoot.strip !== null && lineItem.eid === (sectionRoot.strip.id || sectionRoot.strip.key)) || (!!lineItem.e.label && !!sectionRoot.section.title && I18n.t(lineItem.e.label) === I18n.t(sectionRoot.section.title))
                        dense: true
                        // waits on one switch: shown, greyed (CardGate); a press
                        // on it turns that switch on
                        preview: sectionRoot.gate !== null && sectionRoot.gate.ids.indexOf(lineItem.eid) >= 0
                        previewFix: sectionRoot.gate ? sectionRoot.gate.fix : null
                        // a single picture / editor fills the card
                        fillHeight: sectionRoot.fixed && sectionRoot.single !== null ? Math.max(0, rowsBox.room - Space.s * 2) : (sectionRoot.strip !== null && lineItem.eid === (sectionRoot.strip.id || sectionRoot.strip.key) ? sectionRoot.stripHeight : 0)
                        previousEntry: lineItem.modelData > 0 ? sectionRoot.entries[lineItem.modelData - 1] : null
                    }
                }

                Repeater {
                    id: rows
                    model: sectionRoot.pending || !sectionRoot.shown || sectionRoot.suppressed ? [] : sectionRoot.lines

                    delegate: Row {
                        id: lineRow
                        required property var modelData
                        readonly property var line: lineRow.modelData.rows
                        readonly property var side: lineRow.modelData.side
                        readonly property real picturesW: RowLines.picturesWidth(sectionRoot.entries, lineRow.modelData, rowsColumn.width, Space.m, sectionRoot.pictureMax)
                        function items() {
                            const out = [];
                            for (let j = 0; j < lineRepeater.count; j++)
                                out.push(lineRepeater.itemAt(j));
                            for (let j = 0; j < sideRepeater.count; j++)
                                out.push(sideRepeater.itemAt(j));
                            return out;
                        }
                        function rowWidth(i) {
                            return lineRow.side.length > 0 ? lineRow.picturesW : RowLines.share(sectionRoot.entries, lineRow.line, lineRow.line.indexOf(i), rowsColumn.width, Space.m);
                        }
                        spacing: Space.m * 2

                        Repeater {
                            id: lineRepeater
                            model: lineRow.line
                            delegate: rowDelegate
                        }
                        // short rows beside the pictures
                        Column {
                            id: sideColumn
                            visible: lineRow.side.length > 0
                            // the pictures folded away: the whole line
                            readonly property bool beside: lineRepeater.count > 0 && !!lineRepeater.itemAt(0) && lineRepeater.itemAt(0).visible
                            width: Math.max(0, rowsColumn.width - (sideColumn.beside ? lineRow.picturesW + lineRow.spacing : 0))
                            function rowWidth(i) {
                                return sideColumn.width;
                            }
                            Repeater {
                                id: sideRepeater
                                model: lineRow.side
                                delegate: rowDelegate
                            }
                        }
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
