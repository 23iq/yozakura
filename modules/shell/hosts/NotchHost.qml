import QtQuick

// SurfaceHost contract on the notch (today's behaviour): open() pushes the
// view on the notch StackView and focuses it, close() pops back to the
// resting view. `container` is the notch's NotchAnimationBehavior container.
QtObject {
    id: root

    property var container: null
    property Item view: null
    property bool isOpen: false

    signal closed
    signal requestClose

    function open(v, scr) {
        if (!root.container || !v)
            return;
        root.view = v;
        root.isOpen = true;
        root.container.pushView(v);
        Qt.callLater(() => {
            const stack = root.container ? root.container.stackView : null;
            if (root.isOpen && stack && stack.currentItem === root.view)
                stack.currentItem.forceActiveFocus();
        });
    }

    // This host's view is what the notch shows now.
    readonly property bool onTop: !!root.view && !!root.container && !!root.container.stackView && root.container.stackView.currentItem === root.view

    // Only this host's own view is popped: another surface may be on top.
    function close() {
        const c = root.container;
        if (c && root.onTop && c.stackView.depth > 1) {
            c.stackView.pop();
            c.isShowingDefault = true;
            c.isShowingNotifications = false;
        }
        if (root.isOpen) {
            root.isOpen = false;
            root.closed();
        }
    }
}
