import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.look

// Current weather: symbol, temperature and (option showDescription) the
// condition. Uses WeatherService, refreshed with the rest of the shell.
BarModuleBase {
    id: root

    moduleKey: "weather"

    readonly property bool available: WeatherService.dataAvailable
    readonly property bool showDescription: options.showDescription !== false
    readonly property string temp: Math.round(WeatherService.currentTemp) + "°"

    visible: available
    contentLength: vertical ? column.implicitHeight + Space.m : row.implicitWidth + (flat ? Space.m : Space.xl)

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
        spacing: Space.xs
        // The weather symbol is an emoji: the icon size of the text role.
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherService.weatherSymbol
            font.pixelSize: root.iconSize
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: BarLook.textRole(root.moduleSize)
            tabular: true
            text: root.temp
            font.weight: Look.activeLabelWeight
            color: surface.foreground
        }
        KitText {
            visible: root.showDescription && WeatherService.weatherDescription !== ""
            anchors.verticalCenter: parent.verticalCenter
            role: BarLook.textRole(root.moduleSize)
            text: WeatherService.weatherDescription
            font.weight: root.textWeight
            color: surface.foreground
            opacity: 0.7
        }
    }

    Column {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: WeatherService.weatherSymbol
            font.pixelSize: root.iconSize
        }
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "caption"
            tabular: true
            text: root.temp
            font.weight: Look.activeLabelWeight
            color: surface.foreground
        }
    }
}
