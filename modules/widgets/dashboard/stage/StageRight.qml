import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.widgets.dashboard.home

// The right column of the stage home: NEXT (StageNext, takes the free
// height), the week (StageWeek, opens the month) and the notifications (two
// cards, three where there is room, then they scroll). A detail (`detail`:
// month, wifi, bluetooth, output, input) slides in over it from the right
// while the overview slides a little left and fades; "Done" (or Esc in the
// view) slides it back. The overview keeps its layout underneath, so
// nothing reflows; the left column never moves.
Item {
    id: root

    property var events: []
    property string detail: ""
    // The kind last shown, kept while the panel slides out.
    property string shownKind: ""
    // 0 = overview, 1 = detail (animated).
    property real t: root.detail !== "" ? 1 : 0
    readonly property bool compact: root.height > 0 && root.height < root.naturalHeight - 1
    readonly property real notifStep: notifications.rowH + notifications.rowGap
    readonly property real notifPreferred: notifications.chrome + 2 * root.notifStep - notifications.rowGap
    // Whole cards only: a third when the column has room for it, one on a
    // low screen (the rest scrolls).
    readonly property real notifSpare: root.height - root.naturalHeight
    readonly property int notifRows: root.compact ? 1 : (root.notifSpare >= root.notifStep ? 3 : 2)
    // Fixed by the room, not by the count: arriving or leaving cards never
    // reflow the column.
    readonly property real notifHeight: notifications.chrome + root.notifRows * root.notifStep - notifications.rowGap
    readonly property real naturalHeight: next.naturalHeight + week.implicitHeight + root.notifPreferred + Look.groupGap * 2

    signal openMonth
    signal done

    onDetailChanged: {
        if (root.detail !== "")
            root.shownKind = root.detail;
    }

    implicitHeight: root.naturalHeight

    Behavior on t {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    // The overview clears out early, the detail arrives late: little
    // double exposure while they pass.
    Item {
        objectName: "overview"
        anchors.fill: parent
        opacity: 1 - Math.min(1, root.t * 1.6)
        visible: opacity > 0
        enabled: root.detail === ""
        transform: Translate {
            x: -root.t * Space.xl
        }

        ColumnLayout {
            id: overview
            anchors.fill: parent
            spacing: Look.groupGap

            StageNext {
                id: next
                objectName: "next"
                events: root.events
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: next.minimumHeight
                Layout.preferredHeight: next.naturalHeight
            }

            StageWeek {
                id: week
                objectName: "week"
                divider: true
                events: root.events
                Layout.fillWidth: true
                onOpenMonth: root.openMonth()
            }

            StageNotifications {
                id: notifications
                objectName: "notifications"
                divider: true
                Layout.fillWidth: true
                Layout.preferredHeight: root.notifHeight
            }
        }
    }

    HomeDetail {
        objectName: "detail"
        width: parent.width
        height: parent.height
        kind: root.shownKind
        opacity: Math.max(0, (root.t - 0.35) / 0.65)
        visible: opacity > 0
        enabled: root.detail !== ""
        transform: Translate {
            x: (1 - root.t) * Space.xxl
        }
        onDone: root.done()
        onVisibleChanged: if (!visible)
            root.shownKind = root.detail
    }
}
