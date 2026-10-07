pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One sidebar page: a calm kit ListRow (icon + title), selected while it is
// the current page; an IconButton in the compact sidebar. Keyboard focus is
// the row's hover look.
Item {
    id: navItem

    required property var category
    property bool selected: false
    property bool compact: false
    signal clicked

    implicitHeight: Space.controlM
    height: implicitHeight
    objectName: "nav:" + category.id
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()

    Accessible.role: Accessible.PageTab
    Accessible.name: I18n.t(category.title)

    ListRow {
        anchors.fill: parent
        visible: !navItem.compact
        title: I18n.t(navItem.category.title)
        selected: navItem.selected
        highlighted: navItem.activeFocus
        onClicked: navItem.clicked()
        leading: Component {
            Text {
                text: Icons[navItem.category.icon] ?? ""
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: navItem.selected ? Type.accent : Type.secondary
            }
        }
    }

    IconButton {
        anchors.centerIn: parent
        visible: navItem.compact
        icon: Icons[navItem.category.icon] ?? ""
        active: navItem.selected
        highlighted: navItem.activeFocus
        onClicked: navItem.clicked()
    }
}
