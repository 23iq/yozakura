pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import qs.modules.settings.store
import "../PanelsModel.js" as PanelsModel
import "../../bar/panels/PanelStyles.js" as PanelStyles

// The bars, beside the Bar stage: one entry per bar ("Top bar · Classic"),
// the one being edited ringed (SettingsStore.selectedPanel, shared with the
// stage and the bars editor), its remove action when there are several,
// "Add a bar", and "Back to single bar" under it. A click picks a bar; the
// stage moves it (a click on an edge).
Column {
    id: root

    property var entry
    readonly property var panels: PanelsModel.panelsOf(Config.bar)
    readonly property int current: Math.max(0, Math.min(SettingsStore.selectedPanel, root.panels.length - 1))

    spacing: Space.s

    Repeater {
        model: root.panels
        delegate: Card {
            id: bar
            required property var modelData
            required property int index
            readonly property var style: PanelStyles.get(modelData.style) || {}
            objectName: "panelListItem:" + index
            width: root.width
            padding: Space.m
            interactive: true
            accented: index === root.current && root.panels.length > 1
            onClicked: SettingsStore.selectedPanel = bar.index

            Item {
                width: bar.contentWidth
                height: Math.max(barRow.implicitHeight, Space.controlS)
                IconButton {
                    objectName: "panelRemove:" + bar.index
                    visible: root.panels.length > 1
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: Icons.trash
                    danger: true
                    tooltip: I18n.t("prefs.bar.panels.remove")
                    onClicked: {
                        SettingsStore.transaction("prefs.bar.panels.remove", () => SettingsStore.set("bar.panels", PanelsModel.removePanel(root.panels, bar.index)));
                        SettingsStore.selectedPanel = Math.max(0, bar.index - 1);
                    }
                }
                Row {
                    id: barRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Space.m
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons[bar.style.icon] ?? Icons.squaresFour
                        role: "title"
                        tone: bar.accented ? "accent" : "text"
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        KitText {
                            role: "body"
                            font.weight: Font.DemiBold
                            text: I18n.t("prefs.home.edge." + bar.modelData.edge)
                        }
                        KitText {
                            role: "secondary"
                            text: bar.style.label ? I18n.t(bar.style.label) : ""
                        }
                    }
                }
            }
        }
    }

    Card {
        objectName: "panelListAdd"
        width: root.width
        padding: Space.m
        interactive: true
        fill: false
        onClicked: {
            SettingsStore.transaction("prefs.undo.bar_added", () => SettingsStore.set("bar.panels", PanelsModel.addPanel(root.panels, "classic")));
            SettingsStore.selectedPanel = root.panels.length - 1;
        }
        background: Mark {
            anchors.fill: parent
            radius: Look.bigRadius(Space.controlXL)
            color: "transparent"
            border.width: Space.hairline
            border.color: Qt.alpha(Type.text, 0.25)
        }
        Row {
            spacing: Space.m
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.plus
                role: "title"
                tone: "accent"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                text: I18n.t("prefs.bar.add_bar")
            }
        }
    }

    Chip {
        objectName: "panelListSingle"
        visible: root.panels.length > 1 && !PanelsModel.isLegacy(Config.bar)
        quiet: true
        dense: true
        icon: Icons.arrowCounterClockwise
        text: I18n.t("prefs.bar.panels.single")
        onClicked: {
            SettingsStore.transaction("prefs.bar.panels.single", () => PanelsModel.toSingleBar(root.panels, root.current).forEach(w => SettingsStore.set(w.key, w.value)));
            SettingsStore.selectedPanel = 0;
        }
    }
}
