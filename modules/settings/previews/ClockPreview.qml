import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.settings.controls

// The bar clock as it renders with the current clock options
// (same formats as modules/bar/clock/Clock.qml).
PreviewStage {
    id: root

    property var entry
    property date now: new Date()
    readonly property string time: Qt.formatDateTime(now, Config.bar.use12hFormat ? "h:mm ap" : "hh:mm")
    readonly property string date: Qt.locale().dayName(now.getDay(), Locale.ShortFormat) + " " + now.getDate()

    stageHeight: 84

    Timer {
        interval: 15000
        running: root.visible
        repeat: true
        onTriggered: root.now = new Date()
    }

    StyledRect {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6
        variant: "common"
        width: label.implicitWidth + 36
        height: 36
        radius: Styling.radius(0)
        enableShadow: false

        Behavior on width {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: Config.bar.clockShowDate ? root.time + "  ·  " + root.date : root.time
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(1)
            font.weight: Font.Bold
            color: Colors.overBackground
        }
    }
}
