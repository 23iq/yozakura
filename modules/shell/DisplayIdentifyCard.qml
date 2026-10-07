import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "../settings/displays/DisplayFormat.js" as DisplayFormat

// The big monitor number and connector name of the identify overlay.
// `entry` is {name, index}; `shown` drives the fade.
StyledRect {
    id: card

    property var entry: null
    property bool shown: false
    readonly property var output: DisplayFormat.outputFor(DisplaysService.outputs, entry ? entry.name : "")

    variant: "popup"
    backgroundOpacity: 0.97
    width: 280
    height: 280
    radius: Styling.radius(10)
    enableShadow: true
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.9

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration * 1.5
            easing.type: Motion.enter.easing
        }
    }
    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration * 1.5
            easing.type: Motion.morph.easing
            easing.overshoot: 1.3
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.entry ? card.entry.index : ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(88)
            font.weight: Font.Bold
            color: Colors.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.entry ? card.entry.name : ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(6)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!card.output && !!card.output.model
            text: card.output ? DisplayFormat.title(card.output, card.entry) : ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
        }
    }
}
