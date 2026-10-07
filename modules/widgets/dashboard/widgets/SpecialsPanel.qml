pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.specials
import qs.modules.components.kit

// Dashboard list of the special workspaces (modules/specials): one ListRow
// each (its glyph, name, window count; an open one is selected); click opens
// it (its apps are launched first) and closes the dashboard. A wide tile
// lays them in columns; rows that do not fit are dropped. On compositors without special workspaces:
// a short hint instead.
HostWidget {
    id: root

    readonly property var items: SpecialsService.active ? SpecialsService.items : []
    readonly property int cols: Math.max(1, Math.floor((group.width + Space.s) / (Space.rowHeight * 4)))
    readonly property int capacity: root.cols * Math.max(1, Math.floor((group.bodyHeight + Space.xs) / (Space.rowHeight + Space.xs)))

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.label.specials")

        KitText {
            visible: root.items.length === 0
            width: parent.width
            role: "caption"
            wrapMode: Text.WordWrap
            text: I18n.t(SpecialsService.supported ? "specials.dashboard.empty" : "specials.dashboard.unsupported")
        }

        Grid {
            width: parent.width
            columns: root.cols
            rowSpacing: Space.xs
            columnSpacing: Space.s

            Repeater {
                model: root.items.slice(0, root.capacity)

                ListRow {
                    id: row
                    required property var modelData
                    readonly property int count: SpecialsService.countOf(modelData)
                    objectName: "special:" + modelData.id
                    width: (group.width - group.padding * 2 - Space.s * (root.cols - 1)) / root.cols
                    title: modelData.name
                    subtitle: I18n.tn("specials.windows", row.count)
                    selected: SpecialsService.isOpen(modelData)
                    leading: Component {
                        Text {
                            text: Icons[row.modelData.icon] || Icons.stack
                            font.family: Icons.font
                            font.pixelSize: Type.iconSize("body")
                            color: Colors[row.modelData.accent] ?? Type.secondary
                        }
                    }
                    onClicked: {
                        const id = row.modelData.id;
                        Qt.callLater(() => {
                            Visibilities.setActiveModule("");
                            SpecialsService.toggle(id);
                        });
                    }
                }
            }
        }
    }
}
