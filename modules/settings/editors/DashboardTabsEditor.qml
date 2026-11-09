pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.settings.store
import qs.config
import "../controls"
import "../../widgets/dashboard/DashboardTabs.js" as DashboardTabs
import qs.modules.components.kit

// Dashboard tabs (modules/widgets/dashboard/DashboardTabs.js): rail order
// (drag the grip or use the arrows) and visibility. Writes layout.dashboard.tabs.
ColumnLayout {
    id: root

    property var entry

    spacing: Metrics.spacing

    readonly property var tabs: DashboardTabs.resolve(SettingsStore.get("layout.dashboard.tabs"))
    readonly property int visibleCount: tabs.filter(t => t.visible).length
    readonly property real rowH: Metrics.rowHeight + Metrics.spacing

    function move(id, delta) {
        if (delta !== 0)
            SettingsStore.set("layout.dashboard.tabs", DashboardTabs.move(root.tabs, id, delta));
    }

    function setVisible(id, on) {
        SettingsStore.set("layout.dashboard.tabs", DashboardTabs.setVisible(root.tabs, id, on));
    }

    Repeater {
        model: root.tabs

        delegate: Item {
            id: row

            required property var modelData
            required property int index
            readonly property var meta: DashboardTabs.tabs[DashboardTabs.indexOf(modelData.id)]

            Layout.fillWidth: true
            implicitHeight: Metrics.rowHeight
            z: grip.active ? 2 : 1

            StyledRect {
                id: card
                width: parent.width
                height: parent.height
                y: grip.active ? grip.activeTranslation.y : 0
                variant: grip.active ? "focus" : "common"
                enableShadow: grip.active
                radius: Look.radius("control")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacing
                    anchors.rightMargin: Metrics.spacing * 1.5
                    spacing: Metrics.spacing

                    // Drag grip
                    Icon {
                        role: "title"
                        icon: Icons.dotsNine
                        color: grip.active ? Colors.primary : Colors.outline
                        Accessible.name: I18n.t("prefs.dashboard.drag")

                        HoverHandler {
                            cursorShape: grip.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }
                        DragHandler {
                            id: grip
                            target: null
                            yAxis.enabled: true
                            xAxis.enabled: false
                            onActiveChanged: if (!active)
                                root.move(row.modelData.id, Math.round(activeTranslation.y / root.rowH))
                        }
                    }

                    Column {
                        spacing: 0
                        Repeater {
                            model: [-1, 1]
                            delegate: Icon {
                                id: arrow
                                required property int modelData
                                readonly property bool usable: modelData < 0 ? row.index > 0 : row.index < root.tabs.length - 1
                                icon: modelData < 0 ? Icons.caretUp : Icons.caretDown
                                color: arrowArea.containsMouse && usable ? Colors.primary : Colors.outline
                                opacity: usable ? 1 : 0.3
                                Accessible.role: Accessible.Button
                                Accessible.name: I18n.t(modelData < 0 ? "prefs.dashboard.move_up" : "prefs.dashboard.move_down")
                                MouseArea {
                                    id: arrowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: arrow.usable
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.move(row.modelData.id, arrow.modelData)
                                }
                            }
                        }
                    }

                    Icon {
                        role: "title"
                        icon: row.meta ? (Icons[row.meta.icon] || "") : ""
                        color: row.modelData.visible ? Colors.primary : Colors.outline
                    }

                    KitText {
                        Layout.fillWidth: true
                        text: row.meta ? I18n.t(row.meta.labelKey) : row.modelData.id
                        font.weight: Font.DemiBold
                        color: row.modelData.visible ? Colors.overSurface : Colors.outline
                        elide: Text.ElideRight
                    }

                    ToggleControl {
                        checked: row.modelData.visible
                        // The last visible tab cannot be hidden.
                        enabled: !row.modelData.visible || root.visibleCount > 1
                        Accessible.name: row.meta ? I18n.t(row.meta.labelKey) : ""
                        onToggled: v => root.setVisible(row.modelData.id, v)
                    }
                }
            }
        }
    }
}
