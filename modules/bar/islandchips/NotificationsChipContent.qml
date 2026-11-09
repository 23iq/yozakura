import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The island's bell as a chip: bell, ringing bell with the count while
// there are notifications (Focus mode with hideBadges keeps the plain
// bell), the snoozed bell while do-not-disturb is on. Vertical: the count
// sits under the bell. Used by the bar's notifications module and the
// corner pills.
Item {
    id: root

    property bool vertical: false
    property real moduleSize: 32
    property real glyphSize: 16
    property int textSize: Type.size("body")
    property string textFont: Type.bodyFont
    property color ink: Type.text

    readonly property int count: Notifications.list ? Notifications.list.length : 0
    readonly property bool silent: Notifications.silent === true
    readonly property bool unread: root.count > 0 && !FocusMode.hideBadges
    readonly property string countText: root.count > 99 ? "99+" : String(root.count)

    implicitWidth: root.vertical ? root.moduleSize : content.implicitWidth
    implicitHeight: root.vertical ? content.implicitHeight : root.moduleSize

    Grid {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: root.vertical ? 0 : Space.xs
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
            objectName: "bellGlyph"
            icon: root.silent ? Icons.bellZ : (root.unread ? Icons.bellRinging : Icons.bell)
            size: root.glyphSize
            color: root.ink
            opacity: root.silent ? 0.6 : 1
        }
        // The host's text size and font (island / bar module).
        KitText {
            objectName: "bellCount"
            visible: root.unread
            tabular: true
            text: root.countText
            font.family: root.textFont
            font.pixelSize: root.vertical ? Type.size("caption") : root.textSize
            font.weight: Look.activeLabelWeight
            color: root.ink
        }
    }
}
