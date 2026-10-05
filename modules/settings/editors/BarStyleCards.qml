pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../BarModules.js" as BarModules
import "../Ui.js" as Ui

// Classic vs islands, each previewed with your current module layout.
Item {
    id: root

    property var entry
    readonly property var layout: BarModules.layoutOf(Config.bar.layout)
    readonly property int columns: width < 520 ? 1 : 2

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: [
                {
                    "id": "classic",
                    "title": "shell.bar_style_classic",
                    "subtitle": "prefs.bar.style.classic.desc"
                },
                {
                    "id": "islands",
                    "title": "shell.bar_style_islands",
                    "subtitle": "prefs.bar.style.islands.desc"
                }
            ]

            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: 92
                selected: root.layout.style === modelData.id
                title: I18n.t(modelData.title)
                subtitle: I18n.t(modelData.subtitle)
                onClicked: SettingsStore.set("bar.layout.style", modelData.id)

                ScreenBackdrop {
                    anchors.fill: parent

                    MiniBar {
                        x: 10
                        y: 10
                        width: parent.width - 20
                        unit: 16
                        illustrative: true
                        style: card.modelData.id
                        leftIds: root.layout.left
                        rightIds: root.layout.right
                        drawerIds: root.layout.drawer
                    }
                }
            }
        }
    }
}
