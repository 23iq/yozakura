pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../Ui.js" as Ui

// bar.panels editor: a live schematic of the whole screen, the panel list
// (add / remove), and for the selected panel its edge, style (visual cards),
// behaviour and modules (drag & drop between the style's groups). The first
// edit of a legacy single bar turns it into bar.panels.
Item {
    id: root

    property var entry
    readonly property var panels: PanelsModel.panelsOf(Config.bar)
    property int selected: 0
    readonly property int current: Math.max(0, Math.min(selected, panels.length - 1))
    readonly property var panel: panels.length > 0 ? panels[current] : null
    readonly property bool wide: width >= 640

    implicitHeight: column.implicitHeight

    function commit(list) {
        SettingsStore.set("bar.panels", list);
    }
    function setField(field, value) {
        commit(PanelsModel.setField(panels, current, field, value));
    }

    Column {
        id: column
        width: parent.width
        spacing: 16

        // ── Whole-screen schematic ──
        PreviewStage {
            id: stage
            width: parent.width
            readonly property real screenH: Math.min(Math.round((parent.width - 32) * 9 / 16), 380)
            stageHeight: screenH + 46

            PanelsSchematic {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 32
                width: Math.round(stage.screenH * 16 / 9)
                height: Math.round(width * 9 / 16)
                panels: root.panels
                selected: root.current
                onPicked: index => root.selected = index
            }
        }

        // ── Panel list ──
        Flow {
            width: parent.width
            spacing: 8

            Repeater {
                model: root.panels
                delegate: PillButton {
                    required property var modelData
                    required property int index
                    kind: index === root.current ? "filled" : "ghost"
                    icon: PanelStyles.get(modelData.style).icon
                    text: modelData.id + " · " + I18n.t("common." + modelData.edge)
                    onClicked: root.selected = index
                }
            }
            PillButton {
                icon: "plus"
                text: I18n.t("prefs.bar.panels.add")
                onClicked: {
                    root.commit(PanelsModel.addPanel(root.panels, "classic"));
                    root.selected = root.panels.length;
                }
            }
            PillButton {
                icon: "trash"
                kind: "ghost"
                text: I18n.t("prefs.bar.panels.remove")
                enabled: root.panels.length > 1
                onClicked: {
                    root.commit(PanelsModel.removePanel(root.panels, root.current));
                    root.selected = Math.max(0, root.current - 1);
                }
            }
        }

        // ── Edge + behaviour ──
        Flow {
            width: parent.width
            spacing: 12
            visible: root.panel !== null

            Labeled {
                label: I18n.t("prefs.bar.panels.edge")
                SelectorControl {
                    value: root.panel ? root.panel.edge : "top"
                    options: ["top", "bottom", "left", "right"].map(e => ({
                                "value": e,
                                "label": "common." + e,
                                "icon": {
                                    "top": "arrowUp",
                                    "bottom": "arrowDown",
                                    "left": "arrowLeft",
                                    "right": "arrowRight"
                                }[e]
                            }))
                    onSelected: v => root.setField("edge", v)
                }
            }
            Labeled {
                label: I18n.t("prefs.bar.panels.autohide")
                SelectorControl {
                    value: root.panel ? root.panel.autohide : "auto"
                    options: [
                        {
                            "value": "auto",
                            "label": "prefs.bar.panels.autohide.auto"
                        },
                        {
                            "value": "always",
                            "label": "prefs.bar.panels.autohide.always"
                        },
                        {
                            "value": "never",
                            "label": "prefs.bar.panels.autohide.never"
                        }
                    ]
                    onSelected: v => root.setField("autohide", v)
                }
            }
            Labeled {
                label: I18n.t("prefs.bar.panels.align")
                visible: root.panel !== null && PanelStyles.get(root.panel.style).floating
                SelectorControl {
                    value: root.panel ? root.panel.align : "center"
                    options: [
                        {
                            "value": "start",
                            "label": "prefs.bar.panels.align.start"
                        },
                        {
                            "value": "center",
                            "label": "prefs.bar.panels.align.center"
                        },
                        {
                            "value": "end",
                            "label": "prefs.bar.panels.align.end"
                        }
                    ]
                    onSelected: v => root.setField("align", v)
                }
            }
            Labeled {
                label: I18n.t("prefs.bar.panels.reserve")
                ToggleControl {
                    checked: root.panel ? root.panel.reserve : true
                    onToggled: v => root.setField("reserve", v)
                }
            }
        }

        // ── Style cards ──
        PanelStyleCards {
            width: parent.width
            panel: root.panel
            onPicked: style => root.setField("style", style)
        }

        // ── Modules ──
        ModuleGroupsEditor {
            width: parent.width
            visible: root.panel !== null
            layout: root.panel ? root.panel.groups : ({})
            available: root.panel ? PanelsModel.unused(root.panel) : []
            addGroup: "end"
            groups: root.panel ? PanelsModel.groupsOf(root.panel).map(g => ({
                        "id": g,
                        "icon": PanelsModel.GROUP_ICONS[g],
                        "title": I18n.t(PanelsModel.GROUP_TITLES[g]),
                        "hint": g === "drawer" ? I18n.t("prefs.bar.group.drawer.hint") : (g.indexOf("gap") === 0 ? I18n.t("prefs.bar.group.gap.hint") : "")
                    })) : []
            onMoveRequested: (moduleId, group, index) => root.commit(PanelsModel.moveModule(root.panels, root.current, moduleId, group, index))
        }
    }

    component Labeled: Column {
        id: labeled
        property string label
        default property alias control: holder.data
        spacing: 6
        Text {
            text: labeled.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Bold
            color: Ui.alpha(Colors.overSurfaceVariant, 0.9)
        }
        Item {
            id: holder
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
