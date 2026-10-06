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
    readonly property bool selectorOpen: summaryLoader.item?.selectorOpen ?? false
    readonly property bool selectorHovered: summaryLoader.item?.selectorHovered ?? false
    readonly property bool mediaHovered: !!root.player && summaryHover.hovered && (!selectorHovered || mediaExpanded)
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
    readonly property real contentWidth: 200 + userInfo.width + separator1.width + separator2.width + notifIndicator.width + microphoneWidth + 36 + activitiesWidth
    implicitHeight: Config.notchTheme === "island" ? BarMetrics.notchIslandHeight : BarMetrics.notchRestHeight

    // Edge anchoring avoids a second positioner layout pass at the end of a
    // microphone transition. The bell follows only the animated capsule edge.
    Row {
        id: leadingRow
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        Loader {
            id: timersLoader
            active: root.activitiesOn
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: NotchActivitySegment {
                side: "leading"
                items: root.timerTasks
                motionDuration: root.motionDuration
                tooltipEnabled: !root.panelOpen
                onActivated: (activity, button) => root.segmentClicked("timers", activity, button)
            }
        }
        Loader {
            id: tasksLoader
            active: root.activitiesOn
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: NotchActivitySegment {
                side: "leading"
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
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: NotchActivitySegment {
            side: "trailing"
            items: root.trailingItems
            motionDuration: root.motionDuration
            tooltipEnabled: !root.panelOpen
            onActivated: (activity, button) => root.segmentClicked(root.trailingTrigger, activity, button)
        }
    }

    UserInfo {
        id: userInfo
        anchors.left: leadingRow.right
        anchors.verticalCenter: parent.verticalCenter
    }
    Separator {
        id: separator1
        vert: true
        anchors.left: userInfo.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    NotificationIndicator {
        id: notifIndicator
        anchors.right: trailingLoader.left
        anchors.verticalCenter: parent.verticalCenter
    }
    Item {
        id: micIndicator
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
        vert: true
        anchors.right: micIndicator.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
    Loader {
        id: summaryLoader
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
        }
    }
    Item {
        anchors.left: separator2.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        HoverHandler {
            id: trailingZoneHover
        }
    }
}
