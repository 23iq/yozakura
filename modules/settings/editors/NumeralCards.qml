pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "../../bar/workspaces/WorkspaceNumerals.js" as WorkspaceNumerals
import "../Ui.js" as Ui

// Numeral system picker; every registered system (WorkspaceNumerals.js)
// previewed as workspace pills 1..4.
Item {
    id: root

    property var entry
    readonly property string current: SettingsStore.get("workspaces.numeralStyle") || WorkspaceNumerals.DEFAULT_ID
    readonly property var systems: WorkspaceNumerals.ids()
    readonly property int columns: width < 480 ? 1 : systems.length

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: root.systems

            delegate: ChoiceCard {
                id: card
                required property string modelData
                readonly property var system: WorkspaceNumerals.get(modelData)
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: 58
                selected: root.current === modelData
                title: I18n.t("prefs.numerals." + modelData)
                subtitle: [1, 2, 3, 4, 5].map(n => WorkspaceNumerals.format(modelData, n)).join(" ")
                onClicked: SettingsStore.set("workspaces.numeralStyle", modelData)

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property bool active: index === 1
                            width: active ? 44 : 30
                            height: 30
                            radius: Math.min(Styling.radius(0), 15)
                            color: active ? Colors.primary : Ui.alpha(Colors.overBackground, 0.1)
                            Text {
                                anchors.centerIn: parent
                                text: WorkspaceNumerals.format(card.modelData, parent.index + 1)
                                font.family: card.system && card.system.font && card.system.font.prefer ? card.system.font.prefer[0] : Config.theme.font
                                font.pixelSize: card.modelData === "arabic" ? 14 : 13
                                font.weight: Font.Black
                                color: parent.active ? Colors.overPrimary : Colors.overBackground
                            }
                        }
                    }
                }
            }
        }
    }
}
