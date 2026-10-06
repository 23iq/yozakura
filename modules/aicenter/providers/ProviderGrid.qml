pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/ai/ProviderConnect.js" as Connect

// Step 1 of the Connect sheet: every provider preset as a tile (cloud
// providers, then local servers, then a custom endpoint).
Flickable {
    id: root

    signal picked(string provider)

    readonly property var presets: Connect.presets()
    readonly property int columns: Math.max(1, Math.min(3, Math.floor(width / 190)))

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: root.contentHeight > root.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: BarLook.groupGap

        Repeater {
            model: [
                {
                    id: "cloud",
                    title: "ai.connect.group_cloud",
                    filter: p => !p.local && p.id !== "custom"
                },
                {
                    id: "local",
                    title: "ai.connect.group_local",
                    filter: p => p.local === true || p.id === "custom"
                }
            ]
            delegate: ColumnLayout {
                id: group
                required property var modelData
                Layout.fillWidth: true
                spacing: BarLook.gap
                Text {
                    text: I18n.t(group.modelData.title)
                    font.family: Config.theme.font
                    font.pixelSize: BarLook.font(-2)
                    font.weight: Font.Medium
                    color: Colors.outline
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.columns
                    columnSpacing: BarLook.gap
                    rowSpacing: BarLook.gap
                    Repeater {
                        model: root.presets.filter(group.modelData.filter)
                        delegate: ProviderTile {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            preset: modelData
                            status: Ai.providers ? Ai.providers.status(modelData.id) : ({})
                            onPicked: root.picked(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
