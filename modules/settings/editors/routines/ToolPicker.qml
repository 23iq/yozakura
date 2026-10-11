pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import "../../../routines/RoutineTools.js" as Tools

// Picks the tool of a step: a search box over the catalog (title,
// description) and the tools grouped by what they do (sound & media,
// display & light, focus, apps & windows, ...). `picked(tool)` carries the
// catalog entry.
ColumnLayout {
    id: root

    property var catalog: []
    property var categories: []
    property string current: ""

    signal picked(var tool)

    readonly property var tr: key => I18n.has(key) ? I18n.t(key) : ""
    readonly property var groups: Tools.groups(root.catalog, root.categories, search.input.text, root.tr)

    spacing: Space.s

    TextControl {
        id: search
        objectName: "toolSearch"
        Layout.fillWidth: true
        placeholder: I18n.t("routines.tool_search")
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, Space.px(300))
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: Space.s

            Repeater {
                model: root.groups
                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    SectionLabel {
                        Layout.fillWidth: true
                        text: I18n.t("routines.category." + grp.modelData.category)
                    }
                    Repeater {
                        model: grp.modelData.tools
                        delegate: ListRow {
                            id: row
                            required property var modelData
                            objectName: "tool:" + row.modelData.name
                            Layout.fillWidth: true
                            title: Tools.title(row.modelData, root.tr)
                            subtitle: Tools.description(row.modelData, root.tr)
                            selected: row.modelData.name === root.current
                            onClicked: root.picked(row.modelData)
                        }
                    }
                }
            }

            KitText {
                Layout.fillWidth: true
                visible: root.groups.length === 0
                role: "secondary"
                text: I18n.t("routines.tool_none")
            }
        }
    }
}
