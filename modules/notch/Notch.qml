import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.shell.hosts
import "styles/NotchStyles.js" as NotchStyles
import "NotchShape.js" as NotchShape

Item {
    id: notchContainer

    property bool unifiedEffectActive: false
    z: 1000

    property Component defaultViewComponent
    property Component launcherViewComponent
    property Component dashboardViewComponent
    property Component powermenuViewComponent
    property Component toolsMenuViewComponent
    property Component notificationViewComponent
    property var stackView: stackViewInternal
    // The resting view (stack root), once created
    property var defaultView: null
    property bool isExpanded: stackViewInternal.depth > 1
    property bool parentHovered: false
    property bool isHovered: false

    onParentHoveredChanged: updateChildHover()
    onIsHoveredChanged: updateChildHover()

    function updateChildHover() {
        if (stackViewInternal.currentItem) {
            const h = isHovered || parentHovered;
            if (stackViewInternal.currentItem.hasOwnProperty("notchHovered")) {
                stackViewInternal.currentItem.notchHovered = h;
            }
            if (stackViewInternal.currentItem.hasOwnProperty("parentHoverActive")) {
                stackViewInternal.currentItem.parentHoverActive = h;
            }
        }
    }

    // Screen-specific visibility properties passed from parent
    property var visibilities
    readonly property bool screenNotchOpen: HostRouter.notchOpen(visibilities)
    // Screen this notch is on (notifications.screens filter)
    property string screenName: ""
    readonly property bool hasActiveNotifications: Notifications.notchPopupList.length > 0 && Notifications.showsOnScreen(screenName)

    // notch.style (styles/NotchStyles.js); a collapsing style (pill) sits as
    // a small capsule until something happens or the pointer arrives
    readonly property var styleSpec: NotchStyles.spec(Config.notchStyle)
    readonly property var restingView: stackViewInternal.currentItem
    readonly property bool pillCollapsed: NotchStyles.collapsed(styleSpec, {
        hovered: isHovered || parentHovered,
        open: screenNotchOpen || isExpanded,
        expanded: !!(restingView && restingView.expandedState),
        notifications: hasActiveNotifications,
        activities: !!(restingView && restingView.hasActivities)
    })
    readonly property var capsule: NotchStyles.capsule(Metrics.spacing, vertical)
    // Motion tokens (var: their sub-objects are untyped for qmllint)
    readonly property var motionMorph: Motion.morph
    readonly property var motionEnter: Motion.enter
    readonly property var motionExit: Motion.exit

    // Navigation, rather than visibility signals, owns layout: visibility may
    // change before StackView has selected its incoming item.
    readonly property real contentPadding: isExpanded ? 16 : 0
    readonly property real targetContentWidth: (stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth : 0) + contentPadding * 2
    readonly property real targetContentHeight: (stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight : 0) + contentPadding * 2
    // Depth of the resting notch away from its edge
    readonly property real thickness: Config.notchTheme === "default" ? BarMetrics.notchRestHeight : BarMetrics.notchIslandHeight

    function pushView(view) {
        // StackView records whether the item has an explicit size on load.
        // Prepare persistent views before push so it never takes over sizing.
        prepareView(view);
        return stackViewInternal.push(view);
    }

    function prepareView(view) {
        if (!view)
            return;

        const expanded = view !== stackViewInternal.get(0);
        if (!expanded)
            notchContainer.defaultView = view;
        const inset = expanded ? 16 : 0;
        // Expanded menus retain their natural size while fading out. The
        // default view follows the animated viewport so its media closes with
        // the silhouette; its implicit dimensions remain the geometry target.
        view.width = Qt.binding(() => expanded ? view.implicitWidth : stackViewInternal.width);
        view.height = Qt.binding(() => expanded ? view.implicitHeight : stackViewInternal.height);
        // Preserve the screen-edge origin while the background changes size:
        // views hug the edge and center along it (NotchShape.viewPos).
        const at = () => NotchShape.viewPos(notchContainer.position, {
                w: stackViewInternal.width,
                h: stackViewInternal.height
            }, {
                w: view.width,
                h: view.height
            }, inset);
        view.x = Qt.binding(() => at().x);
        view.y = Qt.binding(() => at().y);
        if (!expanded && view.hasOwnProperty("collapsingStyle"))
            view.collapsingStyle = Qt.binding(() => notchContainer.styleSpec.collapses);
        if (!expanded && view.hasOwnProperty("interactionSuspended")) {
            view.interactionSuspended = Qt.binding(() => screenNotchOpen || stackViewInternal.busy || notchContainer.isExpanded);
        }
    }

    readonly property string position: Config.notchPosition ?? "top"
    // On a side edge the notch stands upright: content stacks along the
    // edge and views open toward the screen center
    readonly property bool vertical: NotchShape.vertical(position)

    // Concave screen corners (attached style only), along the edge
    readonly property int cornerSize: Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property int totalCornerWidth: Config.notchTheme === "default" ? cornerSize * 2 : 0

    readonly property real bodyWidth: isExpanded ? Math.max(targetContentWidth, 290) : targetContentWidth
    readonly property var outerSize: NotchShape.size(position, {
        w: vertical ? Math.max(bodyWidth, thickness) : bodyWidth,
        h: vertical ? targetContentHeight : Math.max(targetContentHeight, thickness)
    }, totalCornerWidth / 2)
    // Target (not animated) size, for placement decisions (NotchAvoidance)
    readonly property real targetWidth: pillCollapsed ? capsule.w : outerSize.w
    readonly property real targetHeight: pillCollapsed ? capsule.h : outerSize.h
    // Resting footprint along the edge: the capsule of a collapsing style
    readonly property real restAlong: styleSpec.collapses ? (vertical ? capsule.h : capsule.w) : (vertical ? targetHeight : targetWidth)
    implicitWidth: targetWidth
    implicitHeight: targetHeight

    // One morph for every size change (Motion.morph): easing and overshoot
    // never switch with the state, so a change that lands mid-animation
    // retargets smoothly instead of restarting with another curve. The
    // resting notch's own media changes keep notch.mediaAnimationDuration.
    readonly property bool restingMorph: !styleSpec.collapses && !vertical && !isExpanded && !screenNotchOpen && !stackViewInternal.busy
    readonly property int geometryAnimationDuration: restingMorph ? Math.min(motionMorph.duration, Math.max(0, Config.notch.mediaAnimationDuration)) : motionMorph.duration
    readonly property int geometryEasing: motionMorph.easing
    readonly property real geometryOvershoot: motionMorph.overshoot

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: notchContainer.geometryAnimationDuration
            easing.type: notchContainer.geometryEasing
            easing.overshoot: notchContainer.geometryOvershoot
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: notchContainer.geometryAnimationDuration
            easing.type: notchContainer.geometryEasing
            easing.overshoot: notchContainer.geometryOvershoot
        }
    }

    // Background (style, edge, radii): never rotated content
    NotchSilhouette {
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: parent.implicitHeight
        position: notchContainer.position
        unifiedEffectActive: notchContainer.unifiedEffectActive
        open: notchContainer.screenNotchOpen || notchContainer.hasActiveNotifications
        tightEdge: notchContainer.hasActiveNotifications && !!stackViewInternal.currentItem && stackViewInternal.depth === 1
        cornerSize: notchContainer.totalCornerWidth / 2
    }

    // Content area: the notch without its concave corners
    Item {
        id: notchRect
        anchors.centerIn: parent
        width: parent.implicitWidth - (notchContainer.vertical ? 0 : notchContainer.totalCornerWidth)
        height: parent.implicitHeight - (notchContainer.vertical ? notchContainer.totalCornerWidth : 0)

        // HoverHandler para detectar hover sin bloquear eventos
        HoverHandler {
            id: notchHoverHandler
            enabled: true

            onHoveredChanged: {
                isHovered = hovered;
            }
        }

        Item {
            id: stackContainer
            anchors.centerIn: parent
            // Clip to the animated silhouette without resizing the views inside.
            width: parent.width
            height: parent.height
            clip: true
            // The pill's capsule shows no content: it fades out before the
            // silhouette shrinks and back in while it grows
            opacity: notchContainer.pillCollapsed ? 0 : 1
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: notchContainer.pillCollapsed ? notchContainer.motionExit.duration : notchContainer.motionEnter.duration
                    easing.type: notchContainer.pillCollapsed ? notchContainer.motionExit.easing : notchContainer.motionEnter.easing
                }
            }

            // Propiedad para controlar el blur durante las transiciones
            property real transitionBlur: 0.0

            // Aplicar MultiEffect con blur animable
            layer.enabled: transitionBlur > 0.0
            layer.effect: MultiEffect {
                blurEnabled: Config.performance.blurTransition
                blurMax: 64
                blur: Math.min(Math.max(stackContainer.transitionBlur, 0.0), 1.0)
            }

            // Animación simple de blur → nitidez durante transiciones
            PropertyAnimation {
                id: blurTransitionAnimation
                target: stackContainer
                property: "transitionBlur"
                from: 1.0
                to: 0.0
                duration: Config.animDuration
                easing.type: Motion.morph.easing
            }

            StackView {
                id: stackViewInternal
                anchors.fill: parent
                initialItem: defaultViewComponent

                onCurrentItemChanged: {
                    notchContainer.prepareView(currentItem);
                    notchContainer.updateChildHover();
                }

                Component.onCompleted: {
                    notchContainer.prepareView(currentItem);
                    isShowingDefault = true;
                    isShowingNotifications = false;
                }

                // Activar blur al inicio de transición y animarlo a nítido
                onBusyChanged: {
                    if (busy) {
                        stackContainer.transitionBlur = 1.0;
                        blurTransitionAnimation.start();
                    }
                }

                pushEnter: NotchViewTransition { entering: true }
                pushExit: NotchViewTransition { entering: false }
                popEnter: NotchViewTransition { entering: true }
                popExit: NotchViewTransition { entering: false }
                replaceEnter: NotchViewTransition { entering: true }
                replaceExit: NotchViewTransition { entering: false }
            }
        }
    }

    // Propiedades para mejorar el control del estado de las vistas
    property bool isShowingNotifications: false
    property bool isShowingDefault: false
}
