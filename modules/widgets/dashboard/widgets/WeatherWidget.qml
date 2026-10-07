pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "WidgetFormat.js" as WidgetFormat

// Weather bento widget (dashboard, clock popup, desktop): a quiet line, the
// condition glyph, the temperature and the condition, with the day's high /
// low, rain and wind as a caption; a tall tile adds the coming days (as many
// as fit) and centres both. The section label's quiet "Debug" action (hover, or while on)
// toggles WeatherService.debugMode (hidden on the desktop:
// `showDebugControls`).
HostWidget {
    id: root

    property bool showDebugControls: true
    // Set by the desktop host; the widget no longer animates.
    property bool animationsEnabled: true

    readonly property bool ready: WeatherService.dataAvailable
    readonly property bool big: group.bodyHeight >= Space.rowHeight * 2.2
    readonly property real dayW: Space.rowHeight * 1.2
    readonly property var days: (WeatherService.forecast || []).slice(1, 1 + Math.max(0, Math.floor(group.width / root.dayW)))
    readonly property bool showDays: root.ready && root.days.length > 1 && group.bodyHeight >= now.height + Space.m + Space.rowHeight * 1.6

    function glyph(code, day) {
        return Icons[WidgetFormat.weatherGlyph(code, day)] || Icons.sun;
    }

    onVisibleChanged: {
        if (visible && !WeatherService.dataAvailable && !WeatherService.isLoading)
            WeatherService.updateWeather();
    }

    HoverHandler {
        id: hover
    }

    Group {
        id: group
        anchors.fill: parent
        fill: true
        bare: !root.framed
        label: I18n.t("bento.widget.weather")
        actionText: root.showDebugControls && (hover.hovered || WeatherService.debugMode) ? I18n.t("bento.weather.debug") : ""
        onActionTriggered: WeatherService.debugMode = !WeatherService.debugMode

        // Centres the line and the days in a tall tile.
        Item {
            visible: root.showDays
            width: 1
            height: Math.max(0, (group.bodyHeight - now.height - days.height - Space.l) / 2 - Space.m)
        }

        Item {
            id: now
            width: parent.width
            height: Math.max(icon.implicitHeight, temp.implicitHeight)

            Text {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                text: root.ready ? root.glyph(WeatherService.effectiveWeatherCode, WeatherService.effectiveIsDay) : Icons.alert
                font.family: Icons.font
                font.pixelSize: Math.round(Type.iconSize("title") * (root.big ? 1.5 : 1))
                color: Type.secondary
            }
            KitText {
                id: temp
                objectName: "weatherTemp"
                anchors.left: icon.right
                anchors.leftMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                visible: root.ready
                role: root.big ? "display" : "title"
                tabular: true
                text: WidgetFormat.temp(WeatherService.currentTemp)
            }
            Column {
                anchors.left: root.ready ? temp.right : icon.right
                anchors.leftMargin: Space.m
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                KitText {
                    width: parent.width
                    role: "body"
                    text: root.ready ? WeatherService.effectiveWeatherDescription : I18n.t("bento.weather.unavailable")
                }
                KitText {
                    width: parent.width
                    visible: root.ready
                    role: "caption"
                    text: WidgetFormat.weatherDetails({
                        "max": WeatherService.maxTemp,
                        "min": WeatherService.minTemp,
                        "rain": WeatherService.rainChance,
                        "wind": group.width > Space.rowHeight * 6.5 ? WeatherService.windSpeed : null
                    }, I18n.t)
                }
            }
        }

        // The coming days
        Row {
            id: days
            visible: root.showDays
            width: parent.width

            Repeater {
                model: root.showDays ? root.days : []

                Column {
                    id: day
                    required property var modelData
                    width: parent.width / root.days.length
                    spacing: Space.xs

                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "caption"
                        text: day.modelData.dayName
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.glyph(day.modelData.weatherCode, true)
                        font.family: Icons.font
                        font.pixelSize: Type.iconSize("body")
                        color: Type.secondary
                    }
                    KitText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        role: "secondary"
                        tabular: true
                        text: WidgetFormat.temp(day.modelData.maxTemp) + " " + WidgetFormat.temp(day.modelData.minTemp)
                    }
                }
            }
        }
    }
}
