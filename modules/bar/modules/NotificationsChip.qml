import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.islandchips

// The idle island's bell in the bar: count + do-not-disturb state
// (NotificationsChipContent). Click opens the history (NotificationsPopup),
// right click toggles do-not-disturb. Shown only while the island does not
// show the bell itself (ShellLayout.homeOf, LayoutModel.js).
BarModuleBase {
    id: root

    moduleKey: "notifications"

    readonly property bool shown: ShellLayout.homeOf("notifications") === "bar"

    visible: root.shown
    contentLength: root.shown ? (root.vertical ? chip.implicitHeight + Space.s * 2 : chip.implicitWidth + (root.flat ? Space.m : Space.l * 1.5)) : 0

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
        active: popup.isOpen
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (point, button) => button === Qt.RightButton ? Notifications.toggleDnd() : popup.toggle()
    }

    NotificationsChipContent {
        id: chip
        anchors.centerIn: parent
        vertical: root.vertical
        moduleSize: root.moduleSize
        glyphSize: root.iconSize
        textSize: root.textSize
        textFont: root.textFont
        ink: surface.foreground
    }

    StyledToolTip {
        show: hover.hovered && !popup.isOpen
        tooltipText: I18n.t(chip.silent ? "bar.notifications.tooltip_silent" : "bar.notifications.tooltip")
    }

    NotificationsPopup {
        id: popup
        anchorItem: surface
        bar: root.bar
    }
}
