import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config

// Header of the composed dashboard: big light clock and date on the left,
// temperature and condition on the right (hidden until the weather loads).
RowLayout {
    id: root

    property date now: new Date()
    readonly property bool use12h: Config.bar.use12hFormat ?? false

    spacing: Metrics.spacing

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignBottom
        spacing: 0

        Text {
            objectName: "clock"
            text: Qt.formatTime(root.now, root.use12h ? "h:mm" : "HH:mm")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(26)
            font.weight: Font.Light
            font.features: {
                "tnum": 1
            }
            color: Colors.overBackground
        }

        Text {
            text: Qt.locale(I18n.resolvedLanguage).toString(root.now, "dddd, MMMM d")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.outline
        }
    }

    Item {
        Layout.fillWidth: true
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignBottom
        spacing: 0
        visible: WeatherService.dataAvailable

        Text {
            Layout.alignment: Qt.AlignRight
            text: Math.round(WeatherService.currentTemp) + "°"
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(4)
            font.weight: Font.Light
            color: Colors.overBackground
        }

        Text {
            Layout.alignment: Qt.AlignRight
            text: WeatherService.weatherDescription
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.outline
        }
    }
}
