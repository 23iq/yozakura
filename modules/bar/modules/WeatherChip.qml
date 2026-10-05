import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services

// Current weather: symbol, temperature and (option showDescription) the
// condition. Uses WeatherService, refreshed with the rest of the shell.
BarModuleBase {
    id: root

    moduleKey: "weather"

    readonly property bool available: WeatherService.dataAvailable
    readonly property bool showDescription: options.showDescription !== false
    readonly property string temp: Math.round(WeatherService.currentTemp) + "°"

    visible: available
    contentLength: vertical ? column.implicitHeight + 12 : row.implicitWidth + (flat ? 12 : 24)

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
    }
    HoverHandler {
        id: hover
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherService.weatherSymbol
            font.pixelSize: root.textSize + 2
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temp
            font.family: Config.theme.font
            font.pixelSize: root.textSize
            font.weight: Font.Bold
            color: surface.foreground
        }
        Text {
            visible: root.showDescription && WeatherService.weatherDescription !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherService.weatherDescription
            font.family: Config.theme.font
            font.pixelSize: root.textSize
            color: surface.foreground
            opacity: 0.7
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: WeatherService.weatherSymbol
            font.pixelSize: root.textSize + 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.temp
            font.family: Config.theme.font
            font.pixelSize: root.smallTextSize
            font.weight: Font.Bold
            color: surface.foreground
        }
    }
}
