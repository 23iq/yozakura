import QtQuick
import qs.modules.services
import qs.modules.components.kit
import qs.config

// Header of the composed dashboard: the time (display) over the date
// (secondary); the weather, temperature over condition, quiet at the right
// (hidden until it loads).
Item {
    id: root

    property date now: new Date()
    readonly property bool use12h: Config.bar.use12hFormat ?? false

    implicitHeight: Math.max(time.implicitHeight, weather.implicitHeight)
    implicitWidth: time.implicitWidth + Space.xl + weather.implicitWidth

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
        anchors.bottom: parent.bottom
        spacing: Space.xs

        KitText {
            objectName: "clock"
            role: "display"
            text: Qt.formatTime(root.now, root.use12h ? "h:mm" : "HH:mm")
        }

        KitText {
            objectName: "date"
            role: "secondary"
            text: Qt.locale(I18n.resolvedLanguage).toString(root.now, "dddd, MMMM d")
        }
    }

    Column {
        id: weather
        objectName: "weather"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Space.xs
        visible: WeatherService.dataAvailable

        KitText {
            anchors.right: parent.right
            role: "body"
            tabular: true
            text: Math.round(WeatherService.currentTemp) + "°"
        }

        KitText {
            anchors.right: parent.right
            role: "caption"
            text: WeatherService.weatherDescription
        }
    }
}
