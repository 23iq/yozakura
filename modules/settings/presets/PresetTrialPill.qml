import QtQuick
import QtQuick.Shapes
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Countdown while a preset is on trial: Keep it, or Revert now; at zero
// the previous look comes back by itself.
Item {
    id: pill

    readonly property bool shown: PresetStudio.trial !== null
    readonly property real progress: PresetStudio.trialLeft / (PresetStudio.trialSeconds * 1000)

    objectName: "presetTrialPill"
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 52
    opacity: shown ? 1 : 0
    visible: opacity > 0
    transform: Translate {
        y: pill.shown ? 0 : -20
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.exit.duration
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainerHighest
        border.width: 1
        border.color: Ui.alpha(Colors.primary, 0.45)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12

        // Countdown ring
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Ui.alpha(Colors.primary, 0.2)
                    strokeWidth: 3
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: 16
                        centerY: 16
                        radiusX: 13
                        radiusY: 13
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    strokeColor: Colors.primary
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: 16
                        centerY: 16
                        radiusX: 13
                        radiusY: 13
                        startAngle: -90
                        sweepAngle: 360 * pill.progress
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: PresetModel.seconds(PresetStudio.trialLeft)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.Bold
                color: Colors.primary
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("prefs.presets.trying", PresetStudio.trial ? PresetStudio.trial.preset : "")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Bold
            color: Colors.overBackground
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "trialRevert"
            kind: "ghost"
            icon: "arrowCounterClockwise"
            text: I18n.t("prefs.presets.revert")
            onClicked: PresetStudio.endTrial(false)
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "trialKeep"
            kind: "filled"
            icon: "accept"
            text: I18n.t("prefs.presets.keep")
            onClicked: PresetStudio.endTrial(true)
        }
    }
}
