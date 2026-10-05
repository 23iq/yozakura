pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../BarModules.js" as BarModules

// Drag & drop editor for the legacy single bar (bar.layout: left / right /
// drawer) with a live mini bar. The editing itself is ModuleGroupsEditor.
Item {
    id: root

    property var entry
    readonly property var layout: BarModules.layoutOf(Config.bar.layout)

    implicitHeight: column.implicitHeight

    function commit(newLayout) {
        SettingsStore.set("bar.layout", {
            "style": layout.style,
            "left": newLayout.left,
            "right": newLayout.right,
            "drawer": newLayout.drawer
        });
    }

    Column {
        id: column
        width: parent.width
        spacing: 14

        PreviewStage {
            width: parent.width
            stageHeight: 92

            ScreenBackdrop {
                anchors.fill: parent
                radius: 0
                opacity: 0.9
            }
            MiniBar {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                width: parent.width - 28
                unit: 24
                style: root.layout.style
                leftIds: editor.display("left").filter(id => id !== "__slot__")
                rightIds: editor.display("right").filter(id => id !== "__slot__")
                drawerIds: editor.display("drawer").filter(id => id !== "__slot__")
                highlightDrawer: editor.dragging && editor.dropGroup === "drawer"
            }
        }

        ModuleGroupsEditor {
            id: editor
            width: parent.width
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
}
