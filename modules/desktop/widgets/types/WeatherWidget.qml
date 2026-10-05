pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.desktop.widgets
import qs.config

// Current conditions (WeatherService, Settings > System > Weather) and, when
// there is room, the next days.
DesktopWidget {
    id: root

    readonly property bool ready: WeatherService.dataAvailable
    readonly property string unit: "°" + (Config.weather.unit ?? "C")
    readonly property var days: (WeatherService.forecast || []).slice(1, 1 + Math.max(0, Math.floor((width - 2 * pad) / (64 * k))))
    readonly property bool showForecast: (options.forecast ?? true) && ready && days.length > 0 && height >= 150 * k

    Component.onCompleted: {
        if (!WeatherService.dataAvailable && !WeatherService.isLoading && !preview)
            WeatherService.updateWeather();
    }

    Item {
        id: now
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.showForecast ? (root.height - 2 * root.pad) * 0.56 : root.height - 2 * root.pad

        Text {
            id: symbol
            anchors.verticalCenter: parent.verticalCenter
            text: root.ready ? WeatherService.weatherSymbol : "·"
            font.pixelSize: Math.round(Math.min(parent.height * 0.8, 64 * root.k))
            color: root.ink
        }

        Column {
            anchors.left: symbol.right
            anchors.leftMargin: Math.round(14 * root.k)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * root.k)

            Text {
                text: root.ready ? Math.round(WeatherService.currentTemp) + root.unit : "--" + root.unit
                font.family: root.font
                font.pixelSize: root.px(12)
                font.weight: Font.DemiBold
                color: root.ink
            }
            Text {
                width: parent.width
                text: root.ready ? WeatherService.weatherDescription : (WeatherService.hasFailed ? I18n.t("desktop.widgets.weather.unavailable") : I18n.t("desktop.widgets.weather.loading"))
                elide: Text.ElideRight
                font.family: root.font
                font.pixelSize: root.px(-1)
                color: root.inkSoft
            }
            Text {
                visible: root.ready
                text: "↑ " + Math.round(WeatherService.maxTemp) + "°  ↓ " + Math.round(WeatherService.minTemp) + "°"
                font.family: root.font
                font.pixelSize: root.px(-2)
                color: root.inkSoft
            }
        }
    }

    Row {
        visible: root.showForecast
        x: root.pad
        anchors.top: now.bottom
        anchors.topMargin: Math.round(6 * root.k)
        width: root.width - 2 * root.pad
        height: root.height - now.height - 2 * root.pad - Math.round(6 * root.k)

        Repeater {
            model: root.days
            Column {
                id: day
                required property var modelData
                width: parent.width / root.days.length
                spacing: Math.round(2 * root.k)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.dayName
                    font.family: root.font
                    font.pixelSize: root.px(-3)
                    font.weight: Font.Bold
                    color: root.inkSoft
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.emoji
                    font.pixelSize: root.px(4)
                    color: root.ink
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(day.modelData.maxTemp) + "° " + Math.round(day.modelData.minTemp) + "°"
                    font.family: root.font
                    font.pixelSize: root.px(-3)
                    color: root.ink
                }
            }
        }
    }
}
