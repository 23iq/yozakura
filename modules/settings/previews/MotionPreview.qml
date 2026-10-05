import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.controls
import "../Ui.js" as Ui

// A pill sliding and a popup opening at the live animation duration.
PreviewStage {
    id: root

    property var entry
    readonly property int duration: Config.theme.animDuration
    property bool flip: false

    stageHeight: 120

    Timer {
        interval: Math.max(root.duration, 120) + 700
        running: root.visible && root.duration > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.flip = !root.flip
    }

    Item {
        id: lane
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.right: popupBox.left
        anchors.rightMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8
        height: 34

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Ui.alpha(Colors.overBackground, 0.1)
        }
        Rectangle {
            id: puck
            anchors.verticalCenter: parent.verticalCenter
            width: 54
            height: 30
            radius: 15
            color: Colors.primary
            x: root.flip ? lane.width - width : 0
            Behavior on x {
                enabled: root.duration > 0
                NumberAnimation {
                    duration: root.duration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Item {
        id: popupBox
        anchors.right: parent.right
        anchors.rightMargin: 34
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 8
        width: 96
        height: 64

        Rectangle {
            anchors.fill: parent
            radius: Math.min(Styling.radius(0), 16)
            color: Colors.surfaceContainerHigh
            border.width: 1
            border.color: Ui.alpha(Colors.primary, 0.4)
            scale: root.flip ? 1 : 0.7
            opacity: root.flip ? 1 : 0
            Behavior on scale {
                enabled: root.duration > 0
                NumberAnimation {
                    duration: root.duration
                    easing.type: Easing.OutBack
                }
            }
            Behavior on opacity {
                enabled: root.duration > 0
                NumberAnimation {
                    duration: root.duration
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: [52, 36]
                    Rectangle {
                        required property int modelData
                        width: modelData
                        height: 6
                        radius: 3
                        color: Ui.alpha(Colors.overBackground, 0.6)
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8
        visible: root.duration === 0
        text: I18n.t("prefs.appearance.anim.off_hint")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }
}
