pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.components
import qs.modules.services.activities
import qs.modules.widgets.defaultview.activities
import qs.config
import "activities/ActivityRegistry.js" as Registry

Item {
    id: root
    required property var player
    property bool hovered: false
    property bool mediaExpanded: false
    // A notch panel is open: segment tooltips would cover its title row
    property bool panelOpen: false
    property bool revealed: true
    property string screenName: ""
    // Upright header of a side-edge notch: segments and the rail
    // (IslandRail) stack along the edge; the summary row is not used
    property bool vertical: false
    readonly property real thickness: Config.notchTheme === "island" ? BarMetrics.notchIslandHeight : BarMetrics.notchRestHeight
    readonly property real railPadding: Math.round(Styling.fontSize(-4))
    readonly property IslandRail rail: railLoader.item as IslandRail
    readonly property bool selectorOpen: summaryLoader.item?.selectorOpen ?? false
    readonly property bool selectorHovered: summaryLoader.item?.selectorHovered ?? false
    readonly property bool mediaHovered: !!root.player && (root.vertical ? (root.rail ? root.rail.mediaHovered : false) : summaryHover.hovered && (!selectorHovered || mediaExpanded))
    readonly property real microphoneWidth: MicrophoneStatus.available && MicrophoneStatus.muted ? Styling.fontSize(4) : 0
    readonly property int motionDuration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration))
    // Live activities flank the content (notch.liveActivities.presentation
    // "notch"): leading segments per task panel (timers, downloads), a
    // trailing privacy segment. Each segment opens its own panel. Order,
    // side and on/off come from notch.activities (ActivityRegistry.js).
    readonly property bool activitiesOn: ActivityService.presentation === "notch"
    readonly property bool hasActivities: root.activitiesOn && ActivityService.count > 0
    readonly property var registry: Registry.resolve(Config.notch ? Config.notch.activities : [])
    readonly property var sides: Registry.sides(ActivityService.activities, root.registry)
    readonly property var timerTasks: root.sides.leading.filter(a => Registry.triggerOf(a, root.registry) === "timers")
    readonly property var otherTasks: root.sides.leading.filter(a => Registry.triggerOf(a, root.registry) !== "timers")
    readonly property var trailingItems: root.sides.trailing
    // Panel a segment opens: its top item's (ephemeral ones open none)
    readonly property string tasksTrigger: root.otherTasks.length ? Registry.triggerOf(root.otherTasks[0], root.registry) : "tasks"
    readonly property string trailingTrigger: root.trailingItems.length ? Registry.triggerOf(root.trailingItems[0], root.registry) : "privacy"
    readonly property NotchActivitySegment timersSegment: timersLoader.item as NotchActivitySegment
    readonly property NotchActivitySegment tasksSegment: tasksLoader.item as NotchActivitySegment
    readonly property NotchActivitySegment trailingSegment: trailingLoader.item as NotchActivitySegment
    readonly property real activitiesWidth: (root.timersSegment ? root.timersSegment.targetWidth : 0) + (root.tasksSegment ? root.tasksSegment.targetWidth : 0) + (root.trailingSegment ? root.trailingSegment.targetWidth : 0)
    readonly property real activitiesHeight: (root.timersSegment ? root.timersSegment.targetHeight : 0) + (root.tasksSegment ? root.tasksSegment.targetHeight : 0) + (root.trailingSegment ? root.trailingSegment.targetHeight : 0)
    // Trigger (see panels/NotchPanels.js) under the pointer, "" when none
    readonly property string hoverTrigger: {
        if (root.timersSegment && root.timersSegment.hovered)
            return "timers";
        if (root.tasksSegment && root.tasksSegment.hovered)
            return root.tasksTrigger;
        if (root.trailingSegment && root.trailingSegment.hovered)
            return root.trailingTrigger;
        if (root.mediaHovered)
            return "media";
        return "";
    }
    // Pointer between an edge and the summary (the segments' side); the
    // overrides force it (tests)
    property bool leadingZoneOverride: false
    property bool trailingZoneOverride: false
    readonly property bool leadingZoneHovered: leadingZoneHover.hovered || root.leadingZoneOverride
    readonly property bool trailingZoneHovered: trailingZoneHover.hovered || root.trailingZoneOverride
    // A segment was clicked (the view decides: open its panel or activate)
    signal segmentClicked(string trigger, var activity, int button)
    // The media title was clicked
    signal mediaClicked
    readonly property real contentWidth: root.vertical ? root.thickness : 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + microphoneWidth + 36 + activitiesWidth
    implicitHeight: root.vertical ? root.railPadding * 2 + root.activitiesHeight + (root.rail ? root.rail.implicitHeight : 0) : root.thickness

    // Edge anchoring avoids a second positioner layout pass at the end of a
    // microphone transition. The bell follows only the animated capsule edge.
    Grid {
        id: leadingRow
        columns: root.vertical ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        anchors.left: root.vertical ? undefined : parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? parent.top : undefined
        anchors.topMargin: root.railPadding
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined

        Loader {
            id: timersLoader
            active: root.activitiesOn
            sourceComponent: NotchActivitySegment {
                side: "leading"
                vertical: root.vertical
                items: root.timerTasks
                motionDuration: root.motionDuration
                tooltipEnabled: !root.panelOpen
                onActivated: (activity, button) => root.segmentClicked("timers", activity, button)
            }
        }
        Loader {
            id: tasksLoader
            active: root.activitiesOn
            sourceComponent: NotchActivitySegment {
                side: "leading"
                vertical: root.vertical
                items: root.otherTasks
                motionDuration: root.motionDuration
                tooltipEnabled: !root.panelOpen
                onActivated: (activity, button) => root.segmentClicked(root.tasksTrigger, activity, button)
            }
        }
    }
    Loader {
        id: trailingLoader
        active: root.activitiesOn
        anchors.right: root.vertical ? undefined : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.top: root.vertical ? railLoader.bottom : undefined
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        sourceComponent: NotchActivitySegment {
            side: "trailing"
            vertical: root.vertical
            items: root.trailingItems
            motionDuration: root.motionDuration
            tooltipEnabled: !root.panelOpen
            onActivated: (activity, button) => root.segmentClicked(root.trailingTrigger, activity, button)
        }
    }

    // Upright: avatar, media disc, mic and bell along the edge
    Loader {
        id: railLoader
        active: root.vertical
        anchors.top: leadingRow.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: IslandRail {
            player: root.player
            motionDuration: root.motionDuration
            onMediaClicked: root.mediaClicked()
        }
    }

    UserInfo {
        id: userInfo
        visible: !root.vertical
        anchors.left: leadingRow.right
        anchors.verticalCenter: parent.verticalCenter
    }
    Separator {
        id: separator1
        visible: !root.vertical
        vert: true
        anchors.left: userInfo.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    NotificationIndicator {
        id: notifIndicator
        visible: !root.vertical
        anchors.right: trailingLoader.left
        anchors.verticalCenter: parent.verticalCenter
    }
    Item {
        id: micIndicator
        visible: !root.vertical
        anchors.right: notifIndicator.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.microphoneWidth
        height: Styling.fontSize(4)
        clip: true
        Behavior on width {
            NumberAnimation {
                duration: root.motionDuration
                easing.type: Easing.OutCubic
            }
        }
        Text {
            anchors.centerIn: parent
            text: Icons.micSlash
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(4)
            color: Colors.criticalRed
            opacity: root.microphoneWidth > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.motionDuration
                }
            }
        }
    }
    Separator {
        id: separator2
        visible: !root.vertical
        vert: true
        anchors.right: micIndicator.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    Loader {
        id: summaryLoader
        active: !root.vertical
        visible: !root.vertical
        anchors.left: separator1.right
        anchors.leftMargin: 4
        anchors.right: separator2.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: Math.min(32, root.implicitHeight)
        sourceComponent: !root.player || Config.notch.disableHoverExpansion ? legacySummary : simpleSummary
        HoverHandler {
            id: summaryHover
        }
        TapHandler {
            enabled: !!root.player
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.mediaClicked()
        }
    }
    Component {
        id: simpleSummary
        MediaSummary {
            player: root.player
            mediaExpanded: root.mediaExpanded
            revealed: root.revealed
        }
    }
    Component {
        id: legacySummary
        CompactPlayer {
            player: root.player
            notchHovered: root.mediaHovered || root.selectorOpen
        }
    }

    // Side zones (see leadingZoneHovered); last so childItems order holds
    Item {
        anchors.left: parent.left
        anchors.right: separator1.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        HoverHandler {
            id: leadingZoneHover
            enabled: !root.vertical
        }
    }
    Item {
        anchors.left: separator2.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        HoverHandler {
            id: trailingZoneHover
            enabled: !root.vertical
        }
    }
}
