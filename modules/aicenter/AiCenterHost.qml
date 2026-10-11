pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import qs.modules.aicenter.common

// Content of the AI bar's own window (AiCenterWindow). The content is created
// lazily on first open and unloaded after `ai.unloadAfterMinutes` closed,
// so an unused AI center costs one empty Item per screen. It only reports
// that the composer wants the keyboard (`focusWanted`); the window decides
// how focus is requested.
Item {
    id: root

    anchors.fill: parent

    required property var targetScreen

    readonly property bool active: Config.ai.enabled !== false && GlobalStates.assistantVisible && targetScreen && targetScreen.name === GlobalStates.assistantScreenName
    property alias hitbox: container
    property bool keepLoaded: false
    // Set by the window: it owns the keyboard right now
    property bool hasKeyboard: false
    // Width the panel may use; the window is only as wide as the panel, so it
    // supplies the screen's width
    property real availableWidth: width
    readonly property bool resizing: resizeHandle.pressed
    readonly property int maxWidth: 900

    signal focusWanted

    readonly property bool onLeft: GlobalStates.assistantPosition === "left"
    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property bool frameWrapped: frameEnabled && GlobalStates.assistantPinned && !GlobalStates.assistantFullscreen
    readonly property int sidebarMargin: frameWrapped || GlobalStates.assistantFullscreen ? 0 : 4
    readonly property int panelWidth: GlobalStates.assistantFullscreen ? width : Math.min(GlobalStates.assistantEffectiveWidth, Math.max(320, availableWidth - 24))

    function focusComposer() {
        const panel = loader.item as AiCenterPanel;
        if (panel)
            panel.focusComposer();
    }

    onActiveChanged: {
        if (active) {
            unloadTimer.stop();
            keepLoaded = true;
            focusWanted();
            Qt.callLater(focusComposer);
        } else {
            unloadTimer.restart();
        }
    }

    Timer {
        id: unloadTimer
        interval: Math.max(1, Config.ai.unloadAfterMinutes ?? 10) * 60000
        onTriggered: if (!root.active)
            root.keepLoaded = false
    }

    Connections {
        target: GlobalStates
        function onAssistantFocusRequested(wasAlreadyOpen) {
            if (root.targetScreen.name !== GlobalStates.assistantScreenName)
                return;
            Qt.callLater(() => {
                if (wasAlreadyOpen && root.active && root.hasKeyboard) {
                    GlobalStates.hideAssistant();
                } else {
                    root.focusWanted();
                    root.focusComposer();
                }
            });
        }
    }

    // Clicking inside the panel takes keyboard focus back.
    MouseArea {
        anchors.fill: container
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (!root.hasKeyboard)
                root.focusWanted();
            mouse.accepted = false;
        }
    }

    MouseArea {
        id: resizeHandle
        width: 8
        height: container.height
        y: container.y
        x: root.onLeft ? container.x + container.width - width : container.x
        visible: container.visible && root.active && !GlobalStates.assistantWide && !GlobalStates.assistantFullscreen
        cursorShape: Qt.SplitHCursor
        preventStealing: true
        property real pressX: 0
        property int pressWidth: 0
        onPressed: {
            pressX = mapToItem(root, mouseX, 0).x;
            pressWidth = GlobalStates.assistantWidth;
        }
        onMouseXChanged: {
            if (!pressed)
                return;
            const x = mapToItem(root, mouseX, 0).x;
            const delta = root.onLeft ? x - pressX : pressX - x;
            GlobalStates.assistantWidth = Math.max(320, Math.min(root.maxWidth, pressWidth + delta));
        }
        onReleased: Config.ai.sidebarWidth = GlobalStates.assistantWidth
    }

    Item {
        id: container

        width: root.panelWidth + root.sidebarMargin
        height: parent.height
        anchors.right: root.onLeft ? undefined : parent.right
        anchors.left: root.onLeft ? parent.left : undefined
        anchors.rightMargin: root.onLeft ? 0 : (root.active ? 0 : -width)
        anchors.leftMargin: root.onLeft ? (root.active ? 0 : -width) : 0
        visible: root.active || slideR.running || slideL.running
        opacity: root.active ? 1 : 0.6

        // Size changes (compact / wide / fullscreen) glide.
        Behavior on width {
            enabled: BarLook.animDuration > 0 && !resizeHandle.pressed
            NumberAnimation {
                duration: BarLook.animDuration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation {
                id: slideR
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on anchors.leftMargin {
            NumberAnimation {
                id: slideL
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
            }
        }

        Loader {
            id: loader
            anchors.fill: parent
            anchors.topMargin: root.sidebarMargin
            anchors.bottomMargin: root.sidebarMargin
            anchors.leftMargin: root.onLeft ? root.sidebarMargin : 0
            anchors.rightMargin: root.onLeft ? 0 : root.sidebarMargin
            active: root.keepLoaded
            sourceComponent: AiCenterPanel {
                frameWrapped: root.frameWrapped
            }
            onLoaded: if (root.active)
                Qt.callLater(root.focusComposer)
        }
    }
}
