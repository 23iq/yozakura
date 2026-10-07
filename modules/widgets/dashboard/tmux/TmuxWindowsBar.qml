pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config

// Horizontally scrollable chips of the selected session's windows. Click
// switches window, double click attaches to the session.
Item {
    id: bar

    required property var tab
    property var currentSession: null

    function isSession(session) {
        return session && !session.isCreateButton && !session.isCreateSpecificButton;
    }

    Flickable {
        anchors.fill: parent
        contentWidth: windowsRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: windowsRow
            spacing: 4
            height: bar.height

            Repeater {
                model: bar.tab.sessionWindows
                delegate: StyledRect {
                    id: windowRect
                    required property var modelData
                    property bool hovered: false
                    variant: {
                        if (windowRect.modelData.active) {
                            return windowRect.hovered ? "primaryfocus" : "primary";
                        } else {
                            return windowRect.hovered ? "focus" : "common";
                        }
                    }
                    width: Math.ceil(windowText.width) + 16
                    height: windowsRow.height
                    radius: Styling.radius(-4)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: windowRect.hovered = true
                        onExited: windowRect.hovered = false

                        onClicked: {
                            if (bar.isSession(bar.currentSession))
                                bar.tab.switchToWindow(bar.currentSession.name, windowRect.modelData.index);
                        }

                        onDoubleClicked: {
                            if (bar.isSession(bar.currentSession))
                                bar.tab.attachToSession(bar.currentSession.name);
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            id: windowText
                            text: windowRect.modelData.index + ": " + windowRect.modelData.name
                            font.family: Config.theme.font
                            font.pixelSize: Config.theme.fontSize
                            font.weight: windowRect.modelData.active ? Font.Bold : Font.Normal
                            color: windowRect.modelData.active ? Colors.overPrimary : Colors.overSurface

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Motion.morph.easing
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
