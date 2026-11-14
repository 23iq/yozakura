pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "../Ui.js" as Ui
import qs.modules.components.kit

// Palette role picker: one swatch per entry option ({value: role | "auto",
// label}), drawn in the live palette so a choice works with every preset
// and light/dark scheme. "auto" is a split swatch (light/dark ink).
Item {
    id: root

    property var entry
    readonly property var current: SettingsStore.get(entry ? entry.key : "")
    readonly property var options: entry ? (entry.options || []) : []

    // balanced rows (9 -> 5 + 4, never 8 + an orphan), each swatch and its
    // name flush left in its cell: the first ring on the row inset, the
    // line of the label above it
    readonly property real cellMin: Space.px(76)
    readonly property int maxCols: Math.max(1, Math.floor((root.width + Space.m) / (root.cellMin + Space.m)))
    readonly property int rows: Math.max(1, Math.ceil(root.options.length / root.maxCols))
    readonly property int cols: Math.max(1, Math.ceil(root.options.length / root.rows))
    readonly property real cellW: Math.max(root.cellMin, (root.width - Space.m * (root.cols - 1)) / root.cols)

    implicitHeight: flow.implicitHeight

    Grid {
        id: flow
        width: parent.width
        columns: root.cols
        columnSpacing: Space.m
        rowSpacing: Space.m

        Repeater {
            model: root.options

            delegate: Item {
                id: swatch
                required property var modelData
                readonly property bool selected: root.current === modelData.value
                readonly property bool auto: modelData.value === "auto"
                readonly property color fill: auto ? Colors.primaryFixed : (Colors[modelData.value] ?? Colors.outline)
                objectName: "swatch:" + modelData.value
                width: root.cellW
                height: ring.height + Space.s + nameText.height
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: I18n.t(modelData.label)
                Accessible.checked: selected
                Keys.onSpacePressed: SettingsStore.set(root.entry.key, modelData.value)

                Rectangle {
                    id: ring
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

                    Icon {
                        role: "caption"
                        visible: swatch.selected
                        anchors.centerIn: parent
                        icon: Icons.accept
                        color: swatch.fill.hslLightness > 0.55 ? Colors.shadow : Colors.white
                    }
                }

                KitText {
                    id: nameText
                    role: "caption"
                    anchors.top: ring.bottom
                    anchors.topMargin: Space.s
                    width: parent.width
                    // a long name on two lines, whole
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideNone
                    text: I18n.t(swatch.modelData.label)
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
