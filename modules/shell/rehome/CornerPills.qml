pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.services.activities
import qs.modules.bar.activities
import qs.modules.shell

// Small pills in the free screen corner (EdgeLayout.freeCorner) for content
// that lost its home: live activities with the notch off and no horizontal
// bar to hold them, the clock and tray with both the bar and notch off
// (ShellLayout.cornerContent). Each pill slides in from its corner.
Item {
    id: root

    // The UnifiedShellPanel (targetScreen, hasFullscreenWindow)
    property var panel: null

    readonly property var content: ShellLayout.cornerContent
    readonly property bool showActivities: root.content.indexOf("activities") !== -1 && ActivityService.presentation === "corner" && ActivityService.count > 0
    readonly property bool showClock: root.content.indexOf("clock") !== -1
    readonly property bool showTray: root.content.indexOf("tray") !== -1
    readonly property bool active: !!panel && !panel.hasFullscreenWindow && (showActivities || showClock || showTray)

    readonly property string corner: panel && panel.targetScreen ? EdgeService.freeCorner(panel.targetScreen, "auto") : "top-right"
    readonly property bool atBottom: corner.indexOf("bottom") === 0
    readonly property bool atRight: corner.indexOf("right") !== -1
    readonly property var insets: panel && panel.targetScreen ? EdgeService.insets(panel.targetScreen) : ({
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        })
    readonly property int gap: Metrics.spacing * 2
    readonly property int pillH: Metrics.badgeHeight + Metrics.spacing * 2
    readonly property var activityList: ActivityService.activities.slice(0, Math.max(1, ActivityService.maxVisible))

    // Input region (UnifiedShellPanel mask)
    readonly property Item hitbox: root.active ? pills : null

    Column {
        id: pills
        objectName: "cornerPills"
        spacing: Metrics.spacing
        x: root.atRight ? root.width - width - root.insets.right - root.gap : root.insets.left + root.gap
        y: root.atBottom ? root.height - height - root.insets.bottom - root.gap : root.insets.top + root.gap
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            x: root.active ? 0 : (root.atRight ? 1 : -1) * root.gap * 2
            Behavior on x {
                NumberAnimation {
                    duration: root.active ? Motion.enter.duration : Motion.exit.duration
                    easing.type: root.active ? Motion.enter.easing : Motion.exit.easing
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.active ? Motion.enter.duration : Motion.exit.duration
                easing.type: root.active ? Motion.enter.easing : Motion.exit.easing
            }
        }

        Pill {
            shown: root.showClock || root.showTray
            Row {
                spacing: Metrics.spacing * 2
                RehomedTray {
                    visible: root.showTray && items.length > 0
                    iconSize: Metrics.iconSize - 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                RehomedClock {
                    visible: root.showClock
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Repeater {
            model: root.showActivities ? root.activityList : []
            Pill {
                id: actPill
                required property var modelData
                shown: true
                ActivityContent {
                    activity: actPill.modelData
                    indicatorSize: Metrics.iconSize - 4
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onTapped: (point, button) => ActivityService.activate(actPill.modelData, button, root.panel.targetScreen.name)
                }
            }
        }
    }

    // One rounded pill hugging its content, aligned to the corner's side
    component Pill: StyledRect {
        id: pill
        property bool shown: true
        default property alias content: inner.data
        variant: "bg"
        visible: pill.shown
        x: root.atRight ? pills.width - width : 0
        width: inner.implicitWidth + Metrics.padding * 2
        height: root.pillH
        radius: height / 2
        Row {
            id: inner
            anchors.centerIn: parent
        }
    }
}
