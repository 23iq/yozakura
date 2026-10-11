import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "../widgets/WidgetFormat.js" as WidgetFormat
import "StageModel.js" as StageModel

// The hero of the stage home while nothing plays: a greeting over a large
// clock, the weather as a large glyph with the temperature and the sky on
// the right (hidden until it loads), and a quiet "nothing playing" line at
// the bottom, so the hero is never a hole. The header then shows only the
// date (StageHeader.showClock).
Item {
    id: root

    property date now: new Date()
    readonly property bool use12h: Config.bar.use12hFormat ?? false
    readonly property real naturalHeight: greeting.implicitHeight + clock.implicitHeight + idle.implicitHeight + Space.xxl * 2

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: time
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -idle.height / 2
        spacing: 0

        KitText {
            id: greeting
            objectName: "greeting"
            role: "title"
            color: Type.secondary
            text: I18n.t(StageModel.greetingKey(root.now.getHours()))
        }

        KitText {
            id: clock
            objectName: "heroClock"
            role: "display"
            font.pixelSize: Math.round(Type.size("display") * 1.6)
            text: Qt.formatTime(root.now, root.use12h ? "h:mm" : "HH:mm")
        }
    }

    Column {
        objectName: "heroWeather"
        anchors.right: parent.right
        anchors.bottom: time.bottom
        anchors.bottomMargin: Space.m
        spacing: Space.xs
        visible: WeatherService.dataAvailable

        Text {
            anchors.right: parent.right
            text: Icons[WidgetFormat.weatherGlyph(WeatherService.effectiveWeatherCode ?? WeatherService.weatherCode, WeatherService.effectiveIsDay ?? true)] || Icons.sun
            font.family: Icons.font
            font.pixelSize: Type.size("display")
            color: Type.secondary
        }

        KitText {
            anchors.right: parent.right
            role: "title"
            tabular: true
            text: WidgetFormat.temp(WeatherService.currentTemp)
        }

        KitText {
            anchors.right: parent.right
            role: "caption"
            text: WeatherService.effectiveWeatherDescription ?? ""
        }
    }

    Row {
        id: idle
        objectName: "nothingPlaying"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        spacing: Space.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.musicNotes
            font.family: Icons.font
            font.pixelSize: Type.iconSize("caption")
            color: Type.muted
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            text: I18n.t("player.nothing_playing")
        }
    }
}
