import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "../components/kit/KitStates.js" as KitStates

// One sidebar destination: icon + title (the icon alone when compact). The
// selection mark is not drawn here: the sidebar slides one accent mark to
// the selected row (SettingsSidebar). Hover shows the language's hover box;
// keyboard focus the kit FocusRing. Up / Down move along the list.
Item {
    id: navItem

    // {id, icon, title} (a Categories.groups destination)
    required property var destination
    property bool selected: false
    property bool compact: false
    readonly property bool hovered: area.containsMouse
    signal clicked

    implicitHeight: Space.controlS
    height: implicitHeight
    objectName: "nav:" + destination.id
    activeFocusOnTab: true
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus()
    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus()

    Accessible.role: Accessible.PageTab
    Accessible.name: I18n.t(destination.title)
    Accessible.selected: selected

    StyledRect {
        anchors.fill: parent
        visible: navItem.hovered && !navItem.selected
        variant: "focus"
        backgroundOpacity: KitStates.opacity("hover", true)
        enableBorder: false
        enableShadow: false
        radius: Look.chipRadius(height)
    }

    FocusRing {
        shown: navItem.activeFocus
        radius: Look.chipRadius(navItem.height) + Space.stroke
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: navItem.compact ? (parent.width - icon.width) / 2 : Look.rowInset
        spacing: Space.m

        Icon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons[navItem.destination.icon] ?? ""
            role: "body"
            tone: navItem.selected ? "accent" : "secondary"
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !navItem.compact
            role: "body"
            text: I18n.t(navItem.destination.title)
            color: navItem.selected ? Type.text : Type.secondary
            font.weight: navItem.selected ? Look.activeLabelWeight : Look.labelWeight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: navItem.clicked()
    }
}
