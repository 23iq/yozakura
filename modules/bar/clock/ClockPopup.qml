import QtQuick
import qs.modules.components
import qs.modules.services

// The clock popup: ClockPanel (column / wide / bento) on a transparent
// BarPopup. Opened by the bar clock and the sentence bar's day and time.
BarPopup {
    id: popup

    property date now: new Date()
    property bool use12h: false

    objectName: "clockPopup"
    variant: "transparent"
    popupPadding: 0

    contentWidth: panel.implicitWidth
    contentHeight: panel.implicitHeight

    onIsOpenChanged: {
        if (isOpen && !WeatherService.dataAvailable)
            WeatherService.updateWeather();
    }

    ClockPanel {
        id: panel
        width: implicitWidth
        height: implicitHeight
        now: popup.now
        use12h: popup.use12h
    }
}
