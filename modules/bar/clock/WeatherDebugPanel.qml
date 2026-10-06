pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

// Weather preview controls of the clock panel, shown while
// WeatherService.debugMode is on (toggled from the weather widget): an hour
// slider and a weather type picker.
ColumnLayout {
    id: root
    spacing: 4

    // Time slider pane
    StyledRect {
        variant: "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 36

        StyledSlider {
            id: sliderContent
            anchors.fill: parent
            anchors.margins: 12
            icon: Icons.clock
            value: WeatherService.debugHour / 24
            tooltipText: {
                var hour = Math.floor(WeatherService.debugHour);
                var minutes = Math.round((WeatherService.debugHour - hour) * 60);
                return hour.toString().padStart(2, '0') + ":" + minutes.toString().padStart(2, '0');
            }
            onValueChanged: WeatherService.debugHour = value * 24
        }
    }

    // Weather type selector pane
    StyledRect {
        id: weatherSelector
        variant: "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 64 + 8

        readonly property int buttonPadding: 4
        readonly property int buttonSpacing: 2

        readonly property var weatherTypes: [
            {
                code: 0,
                icon: "☀️",
                name: "Clear"
            },
            {
                code: 1,
                icon: "🌤️",
                name: "Mainly clear"
            },
            {
                code: 2,
                icon: "⛅",
                name: "Partly cloudy"
            },
            {
                code: 3,
                icon: "☁️",
                name: "Overcast"
            },
            {
                code: 45,
                icon: "🌫️",
                name: "Fog"
            },
            {
                code: 51,
                icon: "🌦️",
                name: "Drizzle"
            },
            {
                code: 61,
                icon: "🌧️",
                name: "Rain"
            },
            {
                code: 65,
                icon: "🌧️",
                name: "Heavy rain"
            },
            {
                code: 71,
                icon: "❄️",
                name: "Snow"
            },
            {
                code: 75,
                icon: "❄️",
                name: "Heavy snow"
            },
            {
                code: 95,
                icon: "⛈️",
                name: "Thunder"
            },
            {
                code: 96,
                icon: "🌩️",
                name: "Hail"
            }
        ]

        readonly property int columns: 6
        readonly property int rows: Math.ceil(weatherTypes.length / columns)

        Grid {
            id: weatherButtonsGrid
            anchors.fill: parent
            anchors.margins: weatherSelector.buttonPadding
            columns: weatherSelector.columns
            rowSpacing: weatherSelector.buttonSpacing
            columnSpacing: weatherSelector.buttonSpacing

            Repeater {
                model: weatherSelector.weatherTypes

                delegate: StyledRect {
                    id: weatherBtn
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: WeatherService.debugWeatherCode === modelData.code
                    readonly property int row: Math.floor(index / weatherSelector.columns)
                    readonly property int col: index % weatherSelector.columns
                    readonly property bool isFirstCol: col === 0
                    readonly property bool isLastCol: col === weatherSelector.columns - 1
                    readonly property bool isFirstRow: row === 0
                    readonly property bool isLastRow: row === weatherSelector.rows - 1
                    property bool buttonHovered: false

                    readonly property real defaultRadius: Styling.radius(0)
                    readonly property real selectedRadius: Styling.radius(0) / 2

                    readonly property real gridWidth: weatherButtonsGrid.width
                    readonly property real gridHeight: weatherButtonsGrid.height

                    variant: isSelected ? "primary" : (buttonHovered ? "focus" : "internalbg")
                    enableShadow: false
                    width: (gridWidth - (weatherSelector.columns - 1) * weatherSelector.buttonSpacing) / weatherSelector.columns
                    height: (gridHeight - (weatherSelector.rows - 1) * weatherSelector.buttonSpacing) / weatherSelector.rows

                    topLeftRadius: isSelected ? (isFirstCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                    topRightRadius: isSelected ? (isLastCol && isFirstRow ? defaultRadius : selectedRadius) : defaultRadius
                    bottomLeftRadius: isSelected ? (isFirstCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius
                    bottomRightRadius: isSelected ? (isLastCol && isLastRow ? defaultRadius : selectedRadius) : defaultRadius

                    Text {
                        anchors.centerIn: parent
                        text: weatherBtn.modelData.icon
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: weatherBtn.buttonHovered = true
                        onExited: weatherBtn.buttonHovered = false
                        onClicked: WeatherService.debugWeatherCode = weatherBtn.modelData.code
                    }

                    StyledToolTip {
                        visible: weatherBtn.buttonHovered
                        tooltipText: weatherBtn.modelData.name
                    }
                }
            }
        }
    }
}
