import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

// SurfaceHost contract (NotchHost implements the same API on the notch):
//   open(view, screen)  shows `view` (reparented into `slot`) on `screen`
//   close()             animates out, then emits closed()
//   isOpen              true between open() and close()
//   requestClose()      Escape, click outside or a lost focus grab; the owner
//                       (HostedSurfaces) clears the Visibilities flag, which
//                       calls close()
// A full-screen overlay layer on one screen. Subclasses place their frame
// from `progress` (0 closed .. 1 open, Motion.enter / Motion.exit; jumps
// straight to the end when animations are off) and set `slot` (HostFrame.slot:
// Escape from the view bubbles up to it).
PanelWindow {
    id: root

    property string hostName: "surface"
    property Item slot: null
    property Item view: null
    property bool isOpen: false
    property real progress: 0

    signal closed
    signal requestClose

    function open(v, scr) {
        if (scr && root.screen !== scr)
            root.screen = scr;
        if (v && v !== root.view) {
            if (root.view && root.view.parent === root.slot)
                root.view.visible = false;
            root.view = v;
        }
        if (root.view && root.slot) {
            root.view.parent = root.slot;
            root.view.anchors.fill = root.slot;
            root.view.visible = true;
        }
        root.isOpen = true;
        root._animate(1, Motion.enter);
        Qt.callLater(root.focusView);
    }

    function close() {
        if (!root.isOpen)
            return;
        root.isOpen = false;
        root._animate(0, Motion.exit);
    }

    function focusView() {
        if (root.isOpen && root.view)
            root.view.forceActiveFocus();
    }

    function _animate(to, token) {
        anim.stop();
        if (token.duration <= 0 || root.progress === to) {
            root.progress = to;
            root._settled();
            return;
        }
        anim.to = to;
        anim.duration = token.duration;
        anim.easing.type = token.easing;
        anim.easing.overshoot = token.overshoot;
        anim.start();
    }

    function _settled() {
        if (!root.isOpen && root.progress === 0)
            root.closed();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        onFinished: root._settled()
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.isOpen || root.progress > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace(root.hostName)
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FocusGrab {
        windows: [root]
        active: root.isOpen
        onCleared: Qt.callLater(() => {
            if (root.isOpen)
                root.requestClose();
        })
    }
}
