pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../Ui.js" as Ui

// Palette role picker: one swatch per entry option ({value: role | "auto",
// label}), drawn in the live palette so a choice works with every preset
// and light/dark scheme. "auto" is a split swatch (light/dark ink).
Item {
    id: root

    property var entry
    readonly property var current: SettingsStore.get(entry ? entry.key : "")
    readonly property var options: entry ? (entry.options || []) : []

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: parent.width
        spacing: 10

        Repeater {
            model: root.options

            delegate: Item {
                id: swatch
                required property var modelData
                readonly property bool selected: root.current === modelData.value
                readonly property bool auto: modelData.value === "auto"
                readonly property color fill: auto ? Colors.primaryFixed : (Colors[modelData.value] ?? Colors.outline)
                objectName: "swatch:" + modelData.value
                width: 64
                height: 66
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: I18n.t(modelData.label)
                Accessible.checked: selected
                Keys.onSpacePressed: SettingsStore.set(root.entry.key, modelData.value)

                Rectangle {
                    id: ring
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 40
                    radius: 20
                    color: "transparent"
                    border.width: swatch.selected || swatch.activeFocus ? 2 : 1
                    border.color: swatch.selected || swatch.activeFocus ? Colors.primary : Ui.alpha(Colors.outlineVariant, 0.9)

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        clip: true
                        color: swatch.fill
                        border.width: 1
                        border.color: Ui.alpha(Colors.overBackground, 0.18)

                        // Auto: light ink on one half, dark ink on the other.
                        Rectangle {
                            visible: swatch.auto
                            x: parent.width / 2
                            width: parent.width / 2
                            height: parent.height
                            color: Colors.overPrimaryFixedVariant
                        }
                    }

                    Text {
                        visible: swatch.selected
                        anchors.centerIn: parent
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 13
                        color: swatch.fill.hslLightness > 0.55 ? Colors.shadow : Colors.white
                    }
                }

                Text {
                    anchors.top: ring.bottom
                    anchors.topMargin: 6
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: I18n.t(swatch.modelData.label)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: swatch.selected ? Font.DemiBold : Font.Normal
                    color: swatch.selected ? Colors.overBackground : Colors.overSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        swatch.forceActiveFocus();
                        SettingsStore.set(root.entry.key, swatch.modelData.value);
                    }
                }
            }
        }
    }
}
