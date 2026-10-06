pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "schema/Categories.js" as Categories

// Sidebar tree: one entry per element page (Categories.groups). A click
// opens the group's first page; the group holding the current page lists
// its pages under itself when it has several.
Flickable {
    id: nav

    property string currentCategory: ""
    property bool compact: false
    readonly property var groups: Categories.sidebar()

    signal categorySelected(string id)

    contentHeight: navColumn.implicitHeight + 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    Column {
        id: navColumn
        x: 10
        width: parent.width - 20
        spacing: 2

        Repeater {
            model: nav.groups

            delegate: Column {
                id: group
                required property var modelData
                readonly property bool open: modelData.categories.some(c => c.id === nav.currentCategory)
                readonly property bool nested: modelData.categories.length > 1
                objectName: "navGroup:" + modelData.id
                width: navColumn.width
                spacing: 2

                NavItem {
                    objectName: "navGroupItem:" + group.modelData.id
                    width: parent.width
                    category: group.modelData
                    compact: nav.compact
                    selected: group.open && !group.nested
                    onClicked: nav.categorySelected(group.modelData.categories[0].id)
                }

                Repeater {
                    model: group.open && group.nested ? group.modelData.categories : []

                    delegate: NavItem {
                        required property var modelData
                        x: nav.compact ? 0 : 18
                        width: group.width - x
                        category: modelData
                        compact: nav.compact
                        selected: nav.currentCategory === modelData.id
                        onClicked: nav.categorySelected(modelData.id)
                    }
                }
            }
        }
    }
}
