import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit

// A toggle chip of the wallpapers tab top bar (per-screen, OLED, tint): the
// kit Chip, active while on. Space/Enter/click toggle it, Tab/Shift+Tab/
// Escape hand focus back to the tab's cyclic keyboard navigation.
Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool toggleEnabled: true
    // Label layout: elided in the middle (monitor name) or whole.
    property bool centerLabel: false
    // Dims the whole control while it cannot be toggled.
    property bool dimWhenDisabled: false
    property bool keyboardNavigationActive: false

    signal toggled
    signal nextRequested
    signal previousRequested
    signal escapeRequested

    function focusToggle() {
        root.keyboardNavigationActive = true;
        chip.forceActiveFocus();
    }

    Layout.preferredWidth: chip.implicitWidth
    Layout.preferredHeight: chip.implicitHeight
    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight
    opacity: root.dimWhenDisabled && !root.toggleEnabled ? 0.5 : 1.0

    Behavior on opacity {
        enabled: Motion.micro.duration > 0
        NumberAnimation {
            duration: Motion.micro.duration
        }
    }

    Chip {
        id: chip
        objectName: "wallpaperToggle"
        anchors.fill: parent
        text: root.label
        active: root.checked
        highlighted: root.keyboardNavigationActive && chip.activeFocus
        maxLabelWidth: root.centerLabel ? Space.controlXL : 0
        onClicked: {
            if (root.toggleEnabled)
                root.toggled();
        }

        onActiveFocusChanged: {
            if (!activeFocus)
                root.keyboardNavigationActive = false;
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) {
                root.keyboardNavigationActive = false;
                if (event.modifiers & Qt.ShiftModifier)
                    root.previousRequested();
                else
                    root.nextRequested();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (root.toggleEnabled)
                    root.toggled();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.keyboardNavigationActive = false;
                root.escapeRequested();
                event.accepted = true;
            }
        }
    }
}
