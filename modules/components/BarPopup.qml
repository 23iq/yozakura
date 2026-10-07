pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.shell
import qs.modules.theme
import qs.modules.components
import qs.config

// BarPopup: A popup component that anchors to bar elements
// Inspired by end-4/dots-hyprland BarPopup implementation
PopupWindow {
    id: root

    // Required: the item this popup anchors to
    required property Item anchorItem
    // Required: the bar panel for position detection
    required property var bar

    // Content to display inside the popup
    default property alias contentData: contentContainer.data

    // Visual configuration
    property int popupPadding: Metrics.spacing
    // Distance from the anchor item (theme.popup.gap)
    property int visualMargin: Config.theme && Config.theme.popup ? Config.theme.popup.gap : 8
    property int shadowMargin: Metrics.padding  // Extra margin for shadow
    property string variant: "popup"  // StyledRect variant for background

    // Behavior configuration
    property bool closeOnFocusLost: true
    // False: no focus grab (a popup opened by hover must not take the
    // pointer from the bar, or leaving its anchor could never be seen)
    property bool claimFocus: true

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    // Optional group identifier. Popups that share a groupId are
    // mutually exclusive: opening one closes the others in the same
    // group. Defaults to "bar" so the bar's flyout controls, clock
    // popups, layout selector, etc. don't stack on top of each other.
    property string groupId: "bar"

    // Extra windows (e.g. a nested child popup) that must not clear
    // this popup's focus grab while they are open.
    property list<var> extraGrabWindows: []

    // Signal emitted when popup is closed externally (click outside)
    signal closedExternally

    // Bar position detection
    readonly property string barPosition: bar?.barPosition ?? "top"

    // Total size including shadow margin. contentWidth/Height are the size the
    // content asks for; the popup follows them through one smooth morph while
    // it is open (it snaps while hidden, so opening never animates).
    readonly property int totalWidth: Math.round(shownWidth) + shadowMargin * 2
    readonly property int totalHeight: Math.round(shownHeight) + shadowMargin * 2
    property int contentWidth: 220
    property int contentHeight: 150
    property real shownWidth: contentWidth
    property real shownHeight: contentHeight
    readonly property bool morphSize: root.visible && root.isOpen && Motion.morph.duration > 0
    Behavior on shownWidth {
        enabled: root.morphSize
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on shownHeight {
        enabled: root.morphSize
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    implicitWidth: totalWidth
    implicitHeight: totalHeight

    // Frame detection
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    // Island tabs hang below the frame, so the frame never pads their popups
    readonly property bool containBar: bar?.contained ?? ((Config.bar?.containBar ?? false) && !(bar?.islandsStyle ?? false))
    readonly property int frameThickness: Config.bar?.frameThickness ?? 0
    readonly property int effectiveFrameOffset: (frameEnabled && containBar) ? frameThickness : 0

    // Placement (EdgeLayout via EdgeService): the popup opens away from the
    // bar edge, flips when it does not fit and stays on screen. Measured on
    // open in the anchor window's coordinates (the bar's full-screen layer).
    // theme.popup.tail: a tail toward the anchor, in front of the gap
    readonly property bool showTail: !!(Config.theme && Config.theme.popup && Config.theme.popup.tail) && variant !== "transparent"
    readonly property int tailSize: showTail ? Metrics.spacing : 0
    readonly property int gap: visualMargin + effectiveFrameOffset + tailSize
    property var anchorRect: ({
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0
        })
    property var area: ({
            "width": 0,
            "height": 0
        })
    readonly property var placement: EdgeService.popupPlacement(area, anchorRect, {
        "w": Math.round(shownWidth),
        "h": Math.round(shownHeight)
    }, barPosition, gap)
    readonly property bool opensVertically: placement.dir === "down" || placement.dir === "up"
    // Anchor center along the popup edge that faces it
    readonly property real anchorAlong: opensVertically ? anchorRect.x + anchorRect.w / 2 - placement.x : anchorRect.y + anchorRect.h / 2 - placement.y

    function measure() {
        if (!anchorItem)
            return;
        const p = anchorItem.mapToItem(null, 0, 0);
        anchorRect = {
            "x": p.x,
            "y": p.y,
            "w": anchorItem.width,
            "h": anchorItem.height
        };
        const win = anchorItem.Window.window;
        const frame = win ? win : (bar && bar.screen ? bar.screen : null);
        area = {
            "width": frame ? frame.width : 0,
            "height": frame ? frame.height : 0
        };
    }

    // anchor.rect is the popup window's top-left relative to anchorItem
    anchor.item: anchorItem
    anchor.rect.x: placement.x - anchorRect.x - shadowMargin
    anchor.rect.y: placement.y - anchorRect.y - shadowMargin
    anchor.rect.width: 0
    anchor.rect.height: 0

    color: "transparent"
    visible: false

    // When true, the transparent shadow margins do not capture input;
    // only the visible content area does. Lets pointer drags from the
    // parent window travel over the margins without breaking its grab.
    property bool clickThroughMargins: false

    Region {
        id: contentInputMask
        item: background
    }

    mask: root.clickThroughMargins ? contentInputMask : null

    // Focus grab for click-outside-to-close behavior
    property bool focusActive: false

    FocusGrab {
        id: focusGrab
        active: root.visible && root.focusActive && root.claimFocus
        windows: [root].concat(root.extraGrabWindows)

        onCleared: {
            // Only one focus grab can exist at a time: a nested child
            // popup starting its own grab clears ours, which is not a
            // request to close while the child is still listed.
            if (root.closeOnFocusLost && root.isOpen && root.extraGrabWindows.length === 0) {
                root.isOpen = false;
                root.closedExternally();
                root.close();
            }
        }
    }

    // theme.popup entry motion toward/away from the anchor + optional tail
    PopupMotion {
        id: motion
        objectName: "popupMotion"
        anchors.fill: parent
        anchors.margins: root.shadowMargin
        dir: root.placement.dir
        anchorAlong: root.anchorAlong
        tail: root.showTail
        tailSize: root.tailSize
        tailVariant: root.variant
        onHidden: {
            if (!root.isOpen)
                root.visible = false;
        }

        StyledRect {
            id: background
            anchors.fill: parent
            variant: root.variant
            glassSurface: "popups"
            enableShadow: true
            radius: Styling.radius(0) // the kit surface radius (Space.surfaceRadius)
            anchorEdge: motion.anchorEdge

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: root.popupPadding
            }
        }
    }

    function open() {
        if (isOpen)
            return;
        closeTimer.stop();
        measure();

        // Group-aware mutual exclusion: ask Visibilities to close any
        // sibling popups already open in the same groupId, then
        // register this popup so future opens in the group close us.
        Visibilities.registerBarPopup(root);

        // Logical state first, then show and animate in
        isOpen = true;
        visible = true;
        motion.shown = true;

        // Grab focus once the window is mapped
        Qt.callLater(() => {
            focusActive = true;
        });
    }

    function close() {
        if (!visible)
            return;

        // Drop our registration so future opens in the same group
        // don't try to close a popup that's already gone.
        Visibilities.unregisterBarPopup(root);

        // Set logical state immediately
        isOpen = false;
        focusActive = false;

        // Animate out; PopupMotion.hidden hides the window (the timer is a
        // safety net for a window that stopped rendering)
        motion.shown = false;
        if (visible)
            closeTimer.restart();
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    // Re-assert the focus grab after it was cleared externally (e.g. a
    // nested child popup took over and then closed)
    function refreshFocusGrab() {
        if (!visible || !isOpen)
            return;
        focusActive = false;
        focusActive = true;
    }

    Timer {
        id: closeTimer
        interval: Motion.exit.duration + 50
        onTriggered: {
            if (!root.isOpen)
                root.visible = false;
        }
    }

    Component.onDestruction: {
        // Make sure a popup that's torn down (parent destroyed, panel
        // reloaded, etc.) doesn't leave a stale entry that blocks
        // future opens in its group.
        Visibilities.unregisterBarPopup(root);
    }
}
