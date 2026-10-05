pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.specials
import qs.config

// Dashboard list of the special workspaces (modules/specials): icon in its
// accent, name, window count, open state; click opens it (its apps are
// launched first) and closes the dashboard. Hidden content on compositors
// without special workspaces: a short hint instead.
StyledRect {
    id: root

    variant: "pane"
    implicitHeight: Math.max(150, column.implicitHeight + 24)

    readonly property var items: SpecialsService.active ? SpecialsService.items : []

    ColumnLayout {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 6

        Text {
            text: I18n.t("specials.dashboard.title")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.Bold
            color: Colors.overSurfaceVariant
        }

        Text {
            visible: root.items.length === 0
            Layout.fillWidth: true
            text: I18n.t(SpecialsService.supported ? "specials.dashboard.empty" : "specials.dashboard.unsupported")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.items
            delegate: StyledRect {
                id: row
                required property var modelData
                readonly property bool open: SpecialsService.isOpen(modelData)
                readonly property int count: SpecialsService.countOf(modelData)
                readonly property color tint: Colors[modelData.accent] ?? Colors.primary
                objectName: "special:" + modelData.id
                Layout.fillWidth: true
                implicitHeight: 40
                variant: area.containsMouse ? "focus" : "internalbg"
                radius: Styling.radius(-2)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    Text {
                        text: Icons[row.modelData.icon] || Icons.stack
                        font.family: Icons.font
                        font.pixelSize: 17
                        color: row.tint
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: row.open ? Font.Bold : Font.Normal
                        color: Colors.overBackground
                        elide: Text.ElideRight
                    }
                    Text {
                        text: I18n.t("specials.windows", row.count)
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: row.open ? row.tint : Colors.outline
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
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
