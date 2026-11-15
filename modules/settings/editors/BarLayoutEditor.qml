pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../BarModules.js" as BarModules
import qs.modules.components.kit

// Drag & drop editor for the single bar (bar.layout: left / right /
// drawer); the page's stage shows the result. The editing itself is
// ModuleGroupsEditor; a move is one undo step.
Item {
    id: root

    property var entry
    // a card of the page row: the compact editor (one group at a time)
    property real fillHeight: 0
    readonly property var layout: BarModules.layoutOf(Config.bar.layout)

    implicitHeight: editor.implicitHeight

    function commit(newLayout) {
        SettingsStore.transaction(root.entry ? root.entry.label : "", () => SettingsStore.set("bar.layout", {
                "style": layout.style,
                "left": newLayout.left,
                "right": newLayout.right,
                "drawer": newLayout.drawer
            }));
    }

    ModuleGroupsEditor {
        id: editor
        objectName: "barModulesEditor"
        width: parent.width
        fillHeight: root.fillHeight
        layout: root.layout
        available: BarModules.unused(root.layout)
        addGroup: "right"
        groups: [
            {
                "id": "left",
                "icon": "alignLeft",
                "title": I18n.t("prefs.bar.group.left")
            },
            {
                "id": "right",
                "icon": "alignRight",
                "title": I18n.t("prefs.bar.group.right")
            },
            {
                "id": "drawer",
                "icon": "caretDoubleLeft",
                "title": I18n.t("prefs.bar.group.drawer"),
                "hint": I18n.t("prefs.bar.group.drawer.hint")
            }
        ]
        onMoveRequested: (moduleId, group, index) => root.commit(BarModules.move(root.layout, moduleId, group, index))
    }
}
