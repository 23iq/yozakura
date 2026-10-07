pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "Ui.js" as Ui

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

    function rowFor(entryId) {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (Ui.prop(r, "entryId") === entryId) {
                expanded = true;
                return r;
            }
        }
        return null;
    }

    function toggle() {
        if (sectionRoot.collapsible)
            sectionRoot.expanded = !sectionRoot.expanded;
    }

    objectName: "settingsSection:" + sectionId
    visible: !section.compositor || YozdService.compositorName === section.compositor
    label: section.title ? I18n.t(section.title) : ""
    actionText: sectionRoot.resetShown ? I18n.t("prefs.common.reset") : (sectionRoot.collapsible ? I18n.t(sectionRoot.expanded ? "prefs.common.hide" : "prefs.common.show") : "")
    onActionTriggered: sectionRoot.resetShown ? SettingsStore.resetSection(sectionRoot.section) : sectionRoot.toggle()

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
            model: sectionRoot.section.entries

            delegate: SettingRow {
                required property var modelData
                width: rowsColumn.width
                entry: modelData
            }
        }
    }
}
