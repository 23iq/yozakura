pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.components.kit
import "schema/Categories.js" as Categories

// Sidebar tree: the element pages in labelled blocks (SectionLabels,
// Categories.sidebarSections), one NavItem row per page. A click opens the
// group's first page; the group holding the current page lists its pages
// under itself (indented) when it has several.
Flickable {
    id: nav

    property string currentCategory: ""
    property bool compact: false
    readonly property var sections: Categories.sidebarSections()

    signal categorySelected(string id)

    contentHeight: navColumn.implicitHeight + Space.l
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    Column {
        id: navColumn
        x: Space.m
        width: parent.width - Space.m * 2
        spacing: Space.l

        Repeater {
            model: nav.sections

            delegate: Column {
                id: block
                required property var modelData
                width: navColumn.width
                spacing: Space.xs / 2

                SectionLabel {
                    x: Space.s
                    width: parent.width - Space.s
                    visible: !nav.compact
                    text: I18n.t(block.modelData.title)
                }

                Repeater {
                    model: block.modelData.groups

                    delegate: Column {
                        id: group
                        required property var modelData
                        readonly property bool open: modelData.categories.some(c => c.id === nav.currentCategory)
                        readonly property bool nested: modelData.categories.length > 1
                        objectName: "navGroup:" + modelData.id
                        width: block.width
                        spacing: Space.xs / 2

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
                                x: nav.compact ? 0 : Space.xl
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
    }
}
