pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui
import "SchemaUtil.js" as SchemaUtil
import "CompositorGate.js" as CompositorGate

// One schema section: a kit Group (its label is the section title) of
// SettingRows. `collapsible: true` sections (the Advanced block) fold behind
// their label (a click on it, or the quiet Show / Hide action), `collapsed`
// sets the initial state; a search jump into a folded section unfolds it.
// A section with changed values offers a quiet Reset action instead.
Group {
    id: sectionRoot

    required property var section
    readonly property string sectionId: section.id
    readonly property bool collapsible: !!section.collapsible
    property bool expanded: !(collapsible && section.collapsed)
    readonly property int modifiedCount: SettingsStore.sectionModifiedCount(section)
    readonly property bool resetShown: sectionRoot.modifiedCount > 0 && sectionRoot.expanded
    readonly property bool allowed: CompositorGate.allows(section.compositor, YozdService.compositorName)
    // Rows are created the first time the section is open and allowed on
    // the running compositor (a folded Advanced block costs nothing); once
    // built (toggle, search jump) folding only hides them.
    property bool opened: false
    // Not built yet: the page fills its sections in a few per frame.
    property bool pending: false

    function rowFor(entryId) {
        const entries = section.entries || [];
        if (!entries.some(e => SchemaUtil.entryId(e) === entryId))
            return null;
        expanded = true;
        opened = true;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (Ui.prop(r, "entryId") === entryId)
                return r;
        }
        return null;
    }

    function toggle() {
        if (!sectionRoot.collapsible)
            return;
        if (sectionRoot.allowed)
            sectionRoot.opened = true;
        sectionRoot.expanded = !sectionRoot.expanded;
    }

    objectName: "settingsSection:" + sectionId
    visible: sectionRoot.allowed && !sectionRoot.pending
    label: section.title ? I18n.t(section.title) : ""
    actionText: sectionRoot.resetShown ? I18n.t("prefs.common.reset") : (sectionRoot.collapsible ? I18n.t(sectionRoot.expanded ? "prefs.common.hide" : "prefs.common.show") : "")
    onActionTriggered: sectionRoot.resetShown ? SettingsStore.requestResetSection(sectionRoot.section) : sectionRoot.toggle()

    // The whole label row of a foldable section toggles it (the action keeps
    // its own clicks: it is above this area).
    MouseArea {
        objectName: "sectionToggle:" + sectionRoot.sectionId
        parent: sectionRoot
        z: -1
        visible: sectionRoot.collapsible
        x: sectionRoot.padding
        y: sectionRoot.padding
        width: sectionRoot.width - sectionRoot.padding * 2 - Space.xxl * 2
        height: Type.size("label") + Space.m
        cursorShape: Qt.PointingHandCursor
        onClicked: sectionRoot.toggle()
    }

    Column {
        id: rowsColumn
        width: parent.width
        visible: sectionRoot.expanded
        spacing: 0

        Repeater {
            id: rows
            model: !sectionRoot.pending && (sectionRoot.opened || (sectionRoot.expanded && sectionRoot.allowed)) ? sectionRoot.section.entries : []

            delegate: SettingRow {
                required property var modelData
                width: rowsColumn.width
                entry: modelData
            }
        }
    }
}
