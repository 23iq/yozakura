import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

// Labelled check box of the wallpapers tab top bar (per-screen, OLED, tint).
// Space/Enter/click toggle it, Tab/Shift+Tab/Escape hand focus back to the
// tab's cyclic keyboard navigation.
Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool toggleEnabled: true
    // Label layout: centred + elided (monitor name) or left-aligned.
    property bool centerLabel: false
    property bool animateLabelColor: true
    // Dims the whole control while it cannot be toggled.
    property bool dimWhenDisabled: false
    property bool keyboardNavigationActive: false

    signal toggled
    signal nextRequested
    signal previousRequested
    signal escapeRequested

    Layout.preferredWidth: 100
    Layout.preferredHeight: 48

    function focusToggle() {
        root.keyboardNavigationActive = true;
        box.forceActiveFocus();
    }

    StyledRect {
        variant: root.keyboardNavigationActive && box.activeFocus ? "focus" : "pane"
        anchors.fill: parent
        radius: Styling.radius(4)
        opacity: root.dimWhenDisabled && !root.toggleEnabled ? 0.5 : 1.0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.background
                radius: Styling.radius(0)

                Text {
                    anchors.fill: parent
                    text: root.label
                    color: Colors.overSurface
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: root.centerLabel ? Text.AlignHCenter : Text.AlignLeft
                    elide: root.centerLabel ? Text.ElideRight : Text.ElideNone
                    leftPadding: root.centerLabel ? 0 : 8

                    Behavior on color {
                        enabled: root.animateLabelColor && Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }

            Item {
                id: box
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                onActiveFocusChanged: {
                    if (!activeFocus) {
                        root.keyboardNavigationActive = false;
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        root.keyboardNavigationActive = false;
                        if (event.modifiers & Qt.ShiftModifier) {
                            root.previousRequested();
                        } else {
                            root.nextRequested();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (root.toggleEnabled) {
                            root.toggled();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.keyboardNavigationActive = false;
                        root.escapeRequested();
                        event.accepted = true;
                    }
                }

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: Styling.radius(0)
                        color: Colors.background
                        visible: !root.checked
                    }

                    StyledRect {
                        variant: "primary"
                        anchors.fill: parent
                        radius: Styling.radius(0)
                        visible: root.checked
                        opacity: root.checked ? 1.0 : 0.0

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.accept
                            color: Styling.srItem("primary")
                            font.family: Icons.font
                            font.pixelSize: 20
                            scale: root.checked ? 1.0 : 0.0

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.toggleEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        if (root.toggleEnabled) {
                            root.toggled();
                        }
                    }
                }
            }
        }
    }
}
