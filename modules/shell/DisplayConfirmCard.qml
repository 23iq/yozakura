import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../settings/Ui.js" as Ui

// "Keep these display settings?": a countdown ring, Keep (Enter, focused) and
// Revert (Esc). The backend reverts on its own when the time runs out.
StyledRect {
    id: root

    readonly property int remaining: DisplaysService.session.remaining
    // Length of the window: the first remaining value of each session
    property int total: 1
    readonly property string sessionId: DisplaysService.session.id
    onSessionIdChanged: root.total = Math.max(DisplaysService.session.remaining, 1)
    readonly property bool urgent: remaining <= 5
    readonly property color ringColor: urgent ? Colors.error : Colors.primary

    variant: "popup"
    backgroundOpacity: 0.97
    radius: Styling.radius(8)
    enableShadow: true
    readonly property int padding: 36
    readonly property int ringSize: 140
    implicitWidth: 460
    implicitHeight: content.implicitHeight + padding * 2
    focus: true

    Keys.onReturnPressed: DisplaysService.keep()
    Keys.onEnterPressed: DisplaysService.keep()
    Keys.onEscapePressed: DisplaysService.revert()

    function takeFocus() {
        keepButton.forceActiveFocus();
    }

    Component.onCompleted: {
        root.total = Math.max(DisplaysService.session.remaining, 1);
        takeFocus();
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width - root.padding * 2
        spacing: 22

        Item {
            id: ringBox
            objectName: "countdownRing"
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.ringSize
            height: root.ringSize
            // Counts down linearly: each second glides to the next value
            property real fraction: Math.min(root.remaining / root.total, 1)

            Behavior on fraction {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Ui.alpha(Colors.overBackground, 0.1)
                    strokeWidth: 8
                    PathAngleArc {
                        centerX: ringBox.width / 2
                        centerY: ringBox.height / 2
                        radiusX: ringBox.width / 2 - 8
                        radiusY: ringBox.height / 2 - 8
                        startAngle: -90
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.ringColor
                    strokeWidth: 8
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ringBox.width / 2
                        centerY: ringBox.height / 2
                        radiusX: ringBox.width / 2 - 8
                        radiusY: ringBox.height / 2 - 8
                        startAngle: -90
                        sweepAngle: 360 * ringBox.fraction
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: -2
                Text {
                    objectName: "countdownText"
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.remaining
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(18)
                    font.weight: Font.Bold
                    color: root.ringColor
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.t("prefs.displays.confirm.seconds")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("prefs.displays.confirm.title")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(5)
                font.weight: Font.Bold
                color: Colors.overBackground
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("prefs.displays.confirm.desc")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            DisplayConfirmButton {
                objectName: "revertButton"
                icon: "arrowCounterClockwise"
                text: I18n.t("prefs.displays.revert")
                keyHint: "Esc"
                onClicked: DisplaysService.revert()
            }
            DisplayConfirmButton {
                id: keepButton
                objectName: "keepButton"
                primary: true
                icon: "accept"
                text: I18n.t("prefs.displays.keep")
                keyHint: "Enter"
                onClicked: DisplaysService.keep()
            }
        }
    }
}
