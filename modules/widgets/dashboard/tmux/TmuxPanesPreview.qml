pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.components.kit
import "../../../components/kit/KitStates.js" as KitStates

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
            // Kit look: the active pane is tinted with the accent, hover is the focus box.
            readonly property string look: KitStates.look(false, !!paneRect.modelData.active, paneRect.hovered)

            x: Math.floor(paneRect.modelData.left * preview.scaleX)
            y: Math.floor(paneRect.modelData.top * preview.scaleY)
            width: Math.floor(paneRect.modelData.width * preview.scaleX) - Space.xs
            height: Math.floor(paneRect.modelData.height * preview.scaleY)
            variant: KitStates.variant(paneRect.look, "transparent")
            backgroundOpacity: KitStates.opacity(paneRect.look, paneRect.hovered)
            radius: Space.controlRadius

            // At rest the pane is a Group box of the language (ink: a hairline).
            Rectangle {
                anchors.fill: parent
                visible: paneRect.look === "normal"
                radius: paneRect.radius
                color: Look.groupBoxed ? Look.groupFill : "transparent"
                border.width: Space.hairline
                border.color: Look.groupBoxed ? Look.groupOutline : Type.hairline
            }

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

            Column {
                anchors.centerIn: parent
                spacing: Space.xs
                width: paneRect.width - Space.l

                KitText {
                    width: parent.width
                    role: "body"
                    text: paneRect.modelData.command
                    color: paneRect.modelData.active ? Type.accent : Type.text
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    visible: paneRect.height > 35
                }

                KitText {
                    width: parent.width
                    role: "caption"
                    tabular: true
                    text: paneRect.modelData.width + "\u00d7" + paneRect.modelData.height
                    horizontalAlignment: Text.AlignHCenter
                    visible: paneRect.height > 70
                }
            }
        }
    }

    // Empty state for panes
    KitText {
        anchors.centerIn: parent
        role: "caption"
        visible: preview.tab.sessionPanes.length === 0 && !preview.tab.loadingSessionInfo
        text: I18n.t("tmux.no_panes")
    }

    // Loading indicator
    Row {
        anchors.centerIn: parent
        spacing: Space.s
        visible: preview.tab.loadingSessionInfo

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.spinnerGap
            font.family: Icons.font
            font.pixelSize: Type.iconSize("body")
            color: Type.muted

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: preview.tab.loadingSessionInfo
            }
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: I18n.t("tmux.loading_panes")
        }
    }
}
