pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.services
import qs.modules.services.activities
import qs.modules.widgets.defaultview.panels
import qs.config
import "activities/ActivityRegistry.js" as Registry
import qs.modules.theme

// Resting notch: the header (user/media/segments) plus, at most one at a
// time, the panel of the segment the pointer rests on (notch.expandOn
// "hover") or that was clicked ("click"); see panels/NotchPanels.js. The
// notch morphs between the collapsed and panel sizes with its own
// geometry animation; panels crossfade while it does. On a side edge
// (notch.position left/right) the header stands upright on the edge and
// panels and notifications open beside it, toward the screen center.
Item {
    id: root
    focus: false
    width: implicitWidth
    height: implicitHeight
    property string screenName: ""
    property bool notchHovered: false
    property bool parentHoverActive: false
    // Set by NotchContent; false while the island is auto-hidden off screen.
    property bool revealed: true
    // Visualizers pause while the island is hidden or covered by another view.
    readonly property bool visualizerShown: revealed && !interactionSuspended
    // Stack transitions freeze idle interaction so closing a launcher cannot
    // simultaneously trigger a second panel.
    property bool interactionSuspended: false
    readonly property var activePlayer: MprisController.activePlayer
    readonly property bool hasActiveNotifications: Notifications.notchPopupList.length > 0 && Notifications.showsOnScreen(root.screenName)
    readonly property string edge: Config.notchPosition ?? "top"
    readonly property bool isBottom: edge === "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"
    // The media summary is the "media" activity (notch.activities)
    readonly property bool mediaEnabled: Registry.isEnabled(Config.notch ? Config.notch.activities : [], "media")
    readonly property bool hasActivities: header.hasActivities

    // ── panels ──
    readonly property var panelAvailability: controller.availability({
        // disableHoverExpansion keeps the compact player instead of a card
        player: root.mediaEnabled && !!root.activePlayer && !Config.notch.disableHoverExpansion,
        transfers: header.activitiesOn ? ActivityService.transfers.length : 0,
        timers: header.activitiesOn ? ActivityService.tasks.filter(a => a.source === "timers").length : 0,
        privacy: header.activitiesOn ? ActivityService.privacy.length : 0,
        voice: VoiceService.panelOpen && (VoiceService.panelScreen === "" || VoiceService.panelScreen === root.screenName),
        timerHub: TimersService.hubOpen && (TimersService.hubScreen === "" || TimersService.hubScreen === root.screenName),
        alarm: TimersService.ringing > 0 && (Config.system?.timers?.alarmPanel ?? true) && (TimersService.alarmScreen === "" || TimersService.alarmScreen === root.screenName)
    })
    readonly property bool clickMode: controller.clickMode
    readonly property bool panelExpanded: controller.expanded
    // The open panel wants keyboard focus / click-outside (registry `modal`)
    readonly property bool modalPanel: controller.modal
    // A panel opened by itself (registry `auto`): the notch must show
    readonly property bool autoPanel: controller.autoOpen
    function dismissPanel() {
        controller.close();
    }
    // Kept for callers/tests that ask whether the notch is expanded
    readonly property bool mediaHoverExpanded: controller.expanded
    readonly property bool expandedState: !interactionSuspended && (controller.expanded || header.hoverTrigger !== "" || notificationHover.hovered || notifications.navigating)

    // Opening a segment's panel widens the notch and moves the segment off
    // the pointer; its side of the header keeps the panel so it does not
    // close and reopen in a loop.
    readonly property bool sideHold: {
        const open = controller.openPanel;
        if (open === "")
            return false;
        if (header.trailingZoneHovered && open === controller.panelFor("privacy"))
            return true;
        return header.leadingZoneHovered && (open === controller.panelFor("timers") || open === controller.panelFor("tasks"));
    }

    NotchPanelController {
        id: controller
        objectName: "panelController"
        mode: Config.notch.expandOn ?? "hover"
        hoverTarget: controller.panelFor(header.hoverTrigger)
        hold: panelHover.hovered || root.sideHold || (controller.openPanel === "media" && (header.selectorOpen || Visibilities.playerMenuOpen))
        suspended: root.interactionSuspended
        available: root.panelAvailability
    }

    // Panel on screen: the open one, or the last one while the notch closes
    property string lastPanel: ""
    readonly property int motionDuration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration))
    Timer {
        id: closeTimer
        interval: root.motionDuration
    }
    Connections {
        target: controller
        function onOpenPanelChanged() {
            if (controller.openPanel !== "") {
                closeTimer.stop();
                root.lastPanel = controller.openPanel;
            } else if (root.motionDuration > 0 && !root.interactionSuspended) {
                closeTimer.restart();
            }
        }
    }
    readonly property string shownPanel: controller.openPanel !== "" ? controller.openPanel : (closeTimer.running ? root.lastPanel : "")
    // implicitHeight of the open panel (set by its Loader)
    property real openPanelHeight: 0
    readonly property real panelWidth: controller.expanded ? controller.widthFor(controller.openPanel, Config.notch.expandedMediaWidth) : 0
    // Width of the panel on screen (kept while it closes, so it is clipped
    // rather than squeezed beside an upright header)
    readonly property real shownPanelWidth: root.shownPanel !== "" ? controller.widthFor(root.shownPanel, Config.notch.expandedMediaWidth) : 0
    readonly property real notificationWidth: hasActiveNotifications ? (expandedState ? 452 : 352) : 0
    readonly property real bodyHeight: (controller.expanded ? root.openPanelHeight : 0) + notificationSlot.height

    implicitWidth: root.vertical ? header.contentWidth + Math.max(root.panelWidth, root.notificationWidth) : Math.max(header.contentWidth, root.panelWidth, root.notificationWidth)
    implicitHeight: root.vertical ? Math.max(header.implicitHeight, root.bodyHeight) : header.implicitHeight + root.bodyHeight

    // Escape closes a clicked-open panel (when the notch layer has focus)
    Keys.onEscapePressed: event => {
        if (controller.expanded) {
            controller.close();
            event.accepted = true;
        }
    }

    function onSegment(trigger, activity, button) {
        if (root.clickMode && button === Qt.LeftButton && root.panelAvailability[controller.panelFor(trigger)])
            controller.toggle(controller.panelFor(trigger));
        else
            ActivityService.activate(activity, button, root.screenName);
    }

    IslandHeader {
        id: header
        objectName: "islandHeader"
        vertical: root.vertical
        width: root.vertical ? contentWidth : parent.width
        height: implicitHeight
        // On the screen edge; centered along a side edge
        x: root.edge === "right" ? root.width - width : 0
        y: root.vertical ? (root.height - height) / 2 : root.isBottom ? root.height - height : 0
        player: root.mediaEnabled ? root.activePlayer : null
        hovered: root.expandedState
        mediaExpanded: controller.openPanel === "media"
        panelOpen: controller.expanded
        revealed: root.visualizerShown
        screenName: root.screenName
        onSegmentClicked: (trigger, activity, button) => root.onSegment(trigger, activity, button)
        onMediaClicked: {
            if (root.clickMode)
                controller.toggle("media");
        }

        // Click mode: a click on the header outside the segments closes
        TapHandler {
            enabled: root.clickMode && controller.expanded
            onTapped: {
                if (header.hoverTrigger === "")
                    controller.close();
            }
        }
    }
    Item {
        id: body
        objectName: "islandBody"
        width: root.vertical ? Math.max(0, parent.width - header.width) : parent.width
        height: root.vertical ? parent.height : panelSlot.height + notificationSlot.height
        // Beside the header, toward the screen center
        x: root.edge === "left" ? header.width : 0
        y: root.vertical ? 0 : root.isBottom ? root.height - header.height - height : header.height

        Item {
            id: panelSlot
            // Follows the notch's animated size (height; width beside an
            // upright header), so the panel is revealed with the silhouette
            width: root.vertical ? (root.shownPanel !== "" ? parent.width : 0) : parent.width
            height: root.vertical ? Math.max(0, parent.height - notificationSlot.height) : root.shownPanel !== "" ? Math.max(0, root.height - header.implicitHeight - notificationSlot.height) : 0
            clip: true
            HoverHandler {
                id: panelHover
                enabled: controller.expanded
            }

            Repeater {
                model: controller.panels
                delegate: Loader {
                    id: panelLoader
                    required property var modelData
                    readonly property bool current: root.shownPanel === panelLoader.modelData.id
                    readonly property NotchPanel panel: panelLoader.item as NotchPanel

                    width: root.vertical ? root.shownPanelWidth : panelSlot.width
                    // Anchor at the edge next to the header
                    x: root.edge === "right" ? panelSlot.width - width : 0
                    y: root.vertical ? (panelSlot.height - height) / 2 : root.isBottom ? panelSlot.height - height : 0
                    height: panelLoader.panel ? panelLoader.panel.implicitHeight : 0
                    active: panelLoader.current || panelLoader.opacity > 0.01
                    source: controller.urlFor(panelLoader.modelData)
                    opacity: panelLoader.current ? 1 : 0
                    visible: opacity > 0.01
                    enabled: panelLoader.current && controller.expanded
                    Behavior on opacity {
                        enabled: root.motionDuration > 0
                        NumberAnimation {
                            duration: root.motionDuration
                            easing.type: Motion.enter.easing
                        }
                    }

                    onLoaded: {
                        const p = panelLoader.panel;
                        if (!p)
                            return;
                        p.screenName = Qt.binding(() => root.screenName);
                        p.revealed = Qt.binding(() => root.visualizerShown && panelLoader.current);
                        p.maxRows = panelLoader.modelData.maxRows || 0;
                        p.closeRequested.connect(controller.close);
                        panelLoader.focusIfModal();
                    }

                    function focusIfModal() {
                        if (panelLoader.isOpen && panelLoader.modelData.modal && panelLoader.panel)
                            panelLoader.panel.forceActiveFocus();
                    }
                    Connections {
                        target: controller
                        function onDismissed(id) {
                            if (id === panelLoader.modelData.id && panelLoader.panel)
                                panelLoader.panel.dismissed();
                        }
                    }

                    // The open panel drives the notch height
                    readonly property bool isOpen: controller.openPanel === panelLoader.modelData.id
                    onIsOpenChanged: {
                        if (panelLoader.isOpen) {
                            root.openPanelHeight = Qt.binding(() => panelLoader.height);
                            panelLoader.focusIfModal();
                        }
                    }
                }
            }
        }
        Item {
            id: notificationSlot
            anchors.top: panelSlot.bottom
            width: parent.width
            height: root.hasActiveNotifications ? notifications.implicitHeight : 0
            clip: true
            HoverHandler {
                id: notificationHover
                enabled: root.hasActiveNotifications
            }
            IslandNotifications {
                id: notifications
                objectName: "islandNotifications"
                anchors.fill: parent
                visible: root.hasActiveNotifications
                hovered: root.expandedState
            }
        }
    }
}
