import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services

// The bar's clock where it lives while the bar is off: a notch segment or a
// corner pill (ShellLayout.homeOf("clock")). A click opens the dashboard.
Text {
    id: root

    property real size: Styling.fontSize(0)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    objectName: "rehomedClock"
    text: Qt.formatDateTime(clock.date, Config.bar && Config.bar.use12hFormat ? "h:mm ap" : "hh:mm")
    color: Colors.overBackground
    font.family: Styling.defaultFont
    font.pixelSize: root.size
    font.weight: Font.DemiBold
    font.features: {
        "tnum": 1
    }
    verticalAlignment: Text.AlignVCenter

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: Visibilities.setActiveModule("dashboard")
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
