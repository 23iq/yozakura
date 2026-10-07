import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../widgets/dashboard/widgets/WidgetFormat.js" as WidgetFormat

// The weather right now as one quiet line: the condition glyph, the
// temperature (title role) and, with `showCondition`, the condition text.
// Nothing while there is no data. `details` is the caption line of the
// day (high / low, rain, wind) for the views that show it under the line.
Row {
    id: root

    property bool showCondition: false
    readonly property bool ready: WeatherService.dataAvailable
    // While the first fetch runs the line keeps its final height (invisible),
    // so the popup does not grow when the data lands.
    readonly property bool pending: !ready && WeatherService.isLoading
    readonly property string details: WidgetFormat.weatherDetails({
        "max": WeatherService.maxTemp,
        "min": WeatherService.minTemp,
        "rain": WeatherService.rainChance,
        "wind": WeatherService.windSpeed
    }, I18n.t)

    visible: root.ready || root.pending
    opacity: root.ready ? 1 : 0
    Behavior on opacity {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: Motion.enter.duration
            easing.type: Motion.enter.easing
        }
    }
    spacing: Space.s

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Icons[WidgetFormat.weatherGlyph(WeatherService.effectiveWeatherCode, WeatherService.effectiveIsDay)] || Icons.sun
        font.family: Icons.font
        font.pixelSize: Type.iconSize("title")
        color: Type.secondary
    }
    KitText {
        objectName: "clockPanelTemp"
        anchors.verticalCenter: parent.verticalCenter
        role: "title"
        tabular: true
        text: WidgetFormat.temp(WeatherService.currentTemp)
    }
    KitText {
        visible: root.showCondition
        anchors.verticalCenter: parent.verticalCenter
        role: "secondary"
        text: WeatherService.effectiveWeatherDescription
    }
}
