pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Scaled layout of the selected session's panes (stretched to fill), with
// an empty state and a loading overlay. Click focuses a pane, double click
// attaches to the session.
Item {
    id: preview

    required property var tab
    property var currentSession: null

    // Layout size in cells; the panes are scaled independently on x and y.
    property real totalWidth: preview.tab.sessionPanes.length > 0 ? preview.tab.sessionPanes[0].totalWidth || 1 : 1
    property real totalHeight: preview.tab.sessionPanes.length > 0 ? preview.tab.sessionPanes[0].totalHeight || 1 : 1
    property real scaleX: width / preview.totalWidth
    property real scaleY: height / preview.totalHeight

    function isSession(session) {
        return session && !session.isCreateButton && !session.isCreateSpecificButton;
    }

    Repeater {
        model: preview.tab.sessionPanes
        delegate: StyledRect {
            id: paneRect
            required property var modelData
            property bool hovered: false
            variant: paneRect.hovered ? "focus" : "pane"

            x: Math.floor(paneRect.modelData.left * preview.scaleX)
            y: Math.floor(paneRect.modelData.top * preview.scaleY)
            width: Math.floor(paneRect.modelData.width * preview.scaleX)
            height: Math.floor(paneRect.modelData.height * preview.scaleY)

            radius: Styling.radius(-2)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: paneRect.hovered = true
                onExited: paneRect.hovered = false

                onClicked: {
                    if (preview.isSession(preview.currentSession))
                        preview.tab.focusPane(preview.currentSession.name, paneRect.modelData.index);
                }

                onDoubleClicked: {
                    if (preview.isSession(preview.currentSession))
                        preview.tab.attachToSession(preview.currentSession.name);
                }
            }

            // Active border overlay
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: paneRect.modelData.active ? 2 : 0
                border.color: paneRect.modelData.active ? Styling.srItem("overprimary") : "transparent"
                radius: paneRect.radius

                Behavior on border.width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }

                Behavior on border.color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                width: paneRect.width - 16

                // Command
                Text {
                    width: parent.width
                    text: paneRect.modelData.command
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    font.weight: Font.Bold
                    color: Colors.overSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    visible: paneRect.height > 35

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }

                // Dimensions info
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: paneRect.modelData.width + "×" + paneRect.modelData.height
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.outline
                    opacity: 0.7
                    visible: paneRect.height > 70

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }
                }
            }
        }
    }

    // Empty state for panes
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: preview.tab.sessionPanes.length === 0 && !preview.tab.loadingSessionInfo

        Text {
            text: Icons.terminalWindow
            font.family: Icons.font
            font.pixelSize: 32
            color: Colors.outline
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
        }

        Text {
            text: I18n.t("tmux.no_panes")
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.outline
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Loading indicator
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        visible: preview.tab.loadingSessionInfo

        Row {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: Icons.spinnerGap
                font.family: Icons.font
                font.pixelSize: 20
                color: Styling.srItem("overprimary")
                textFormat: Text.RichText

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: preview.tab.loadingSessionInfo
                }
            }

            Text {
                text: I18n.t("tmux.loading_panes")
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize
                color: Colors.outline
            }
        }
    }
}
