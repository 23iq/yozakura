pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import "../Ui.js" as Ui

// Bar edge picker: four screens with the bar (and frame, when enabled)
// drawn where it would sit.
Item {
    id: root

    property var entry
    readonly property string position: SettingsStore.get("bar.position") || "top"
    readonly property int columns: width < 560 ? 2 : 4

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: [
                {
                    "id": "top",
                    "label": "common.top",
                    "icon": "arrowUp"
                },
                {
                    "id": "bottom",
                    "label": "common.bottom",
                    "icon": "arrowDown"
                },
                {
                    "id": "left",
                    "label": "common.left",
                    "icon": "arrowLeft"
                },
                {
                    "id": "right",
                    "label": "common.right",
                    "icon": "arrowRight"
                }
            ]

            delegate: ChoiceCard {
                id: card
                required property var modelData
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * 0.52)
                selected: root.position === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.label)
                onClicked: SettingsStore.set("bar.position", modelData.id)

                ScreenMock {
                    anchors.fill: parent
                    edge: card.modelData.id
                }
            }
        }
    }

    component ScreenMock: ScreenBackdrop {
        id: screen
        property string edge: "top"
        readonly property bool vertical: edge === "left" || edge === "right"
        readonly property real frame: Config.bar.frameEnabled ? Math.max(2, Config.bar.frameThickness * 0.35) : 0
        readonly property real thick: 9

        // Frame
        Rectangle {
            anchors.fill: parent
            visible: screen.frame > 0
            color: "transparent"
            radius: screen.radius
            border.width: screen.frame
            border.color: Colors.background
        }

        StyledRect {
            variant: "barbg"
            enableShadow: false
            backgroundOpacity: Math.max(Config.theme.srBarBg.opacity ?? 1, 0.9)
            radius: Math.min(Styling.radius(0), screen.thick / 2)
            x: screen.edge === "right" ? parent.width - width - 4 - screen.frame : 4 + screen.frame
            y: screen.edge === "bottom" ? parent.height - height - 4 - screen.frame : 4 + screen.frame
            width: screen.vertical ? screen.thick : parent.width - 8 - screen.frame * 2
            height: screen.vertical ? parent.height - 8 - screen.frame * 2 : screen.thick

            Grid {
                anchors.centerIn: parent
                columns: screen.vertical ? 1 : 5
                spacing: 3
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: index === 0 ? 3 : 3
                        height: 3
                        radius: 1.5
                        color: index === 0 ? Colors.primary : Ui.alpha(Colors.overSurfaceVariant, 0.6)
                    }
                }
            }
        }

        // Window
        Rectangle {
            readonly property real inset: 4 + screen.frame + screen.thick + 5
            x: screen.edge === "left" ? inset : 8 + screen.frame
            y: screen.edge === "top" ? inset : 8 + screen.frame
            width: parent.width - (screen.vertical ? inset : 8 + screen.frame) - 8 - screen.frame
            height: parent.height - (screen.vertical ? 8 + screen.frame : inset) - 8 - screen.frame
            radius: Math.min(Styling.radius(-4), 8)
            color: Ui.alpha(Colors.surfaceContainerHigh, 0.85)
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.8)
        }
    }
}
