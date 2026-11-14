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
    readonly property int columns: Math.max(1, Math.min(4, Math.floor(width / 190)))

    // A group's columns: the most that fit, or one fewer when that fills
    // every line (8 cloud providers in two lines of 4, 3 local ones in one
    // line: no lone hole at the end of a group).
    function columnsFor(n) {
        for (let c = root.columns; c >= Math.max(2, root.columns - 1); c--) {
            if (n % c === 0)
                return c;
        }
        return root.columns;
    }

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
                AiText {
                    role: "caption"
                    text: I18n.t(group.modelData.title)
                    font.weight: Font.Medium
                }
                GridLayout {
                    readonly property var items: root.presets.filter(group.modelData.filter)
                    Layout.fillWidth: true
                    columns: root.columnsFor(items.length)
                    columnSpacing: BarLook.gap
                    rowSpacing: BarLook.gap
                    Repeater {
                        model: parent.items
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
