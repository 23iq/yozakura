import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.presets

// Preset switcher (bar button, `<app> run presets`): the thumbnail gallery
// over a dimmed screen. Hover previews live; Enter keeps, Esc/close reverts.
PanelWindow {
    id: presetsPopup

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("presets")
    WlrLayershell.keyboardFocus: presetsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool presetsOpen: screenVisibilities ? screenVisibilities.presets : false

    visible: presetsOpen
    exclusionMode: ExclusionMode.Ignore

    // Mask to capture input on the entire window when open
    mask: Region {
        item: presetsOpen ? fullMask : emptyMask
    }

    // Full screen mask when open
    Item {
        id: fullMask
        anchors.fill: parent
    }

    // Empty mask when hidden
    Item {
        id: emptyMask
        width: 0
        height: 0
    }

    FocusGrab {
        id: focusGrab
        windows: [presetsPopup]
        active: presetsOpen

        onCleared: {
            // Use Qt.callLater to avoid potential race conditions
            Qt.callLater(() => {
                if (presetsOpen) {
                    Visibilities.setActiveModule("");
                }
            });
        }
    }

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Colors.scrim
        opacity: presetsOpen ? 0.5 : 0

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Visibilities.setActiveModule("");
            }
        }
    }

    // The gallery card, centered (search, tabs, thumbnails)
    StyledRect {
        id: panel
        variant: "popup"
        anchors.centerIn: parent
        width: gallery.implicitWidth
        height: gallery.implicitHeight
        radius: Styling.radius(20)
        enableShadow: true
        opacity: presetsOpen ? 1 : 0
        scale: presetsOpen ? 1 : 0.94

        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }

        Behavior on scale {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
                easing.overshoot: Motion.enter.overshoot
            }
        }

        // A click on the card must not reach the backdrop
        MouseArea {
            anchors.fill: parent
        }

        PresetsGallery {
            id: gallery
            anchors.fill: parent
            focus: true
            onCloseRequested: Visibilities.setActiveModule("")
        }
    }

    onPresetsOpenChanged: {
        if (presetsOpen)
            Qt.callLater(() => gallery.forceActiveFocus());
    }
    Component.onCompleted: {
        if (presetsOpen)
            Qt.callLater(() => gallery.forceActiveFocus());
    }
}
