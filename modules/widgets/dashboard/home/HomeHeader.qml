import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "../widgets/WidgetFormat.js" as WidgetFormat

// Header of the composed dashboard: the time as the hero (display) over the
// date (secondary); the weather as a glyph and the temperature, quiet at the
// right (hidden until it loads).
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
        anchors.verticalCenter: parent.verticalCenter
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

    Row {
        id: weather
        objectName: "weather"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Space.s
        spacing: Space.s
        visible: WeatherService.dataAvailable

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons[WidgetFormat.weatherGlyph(WeatherService.effectiveWeatherCode ?? WeatherService.weatherCode, WeatherService.effectiveIsDay ?? true)] || Icons.sun
            font.family: Icons.font
            font.pixelSize: Type.iconSize("title")
            color: Type.secondary
        }

        KitText {
            objectName: "temperature"
            anchors.verticalCenter: parent.verticalCenter
            role: "title"
            tabular: true
            text: WidgetFormat.temp(WeatherService.currentTemp)
        }
    }
}
