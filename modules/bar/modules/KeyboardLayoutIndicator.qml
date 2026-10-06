import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services

// Active keyboard layout (EN, RU...). Click switches to the next layout, the
// wheel cycles. Hidden unless more than one layout is configured and
// keyboard.showIndicator is on.
BarModuleBase {
    id: root

    moduleKey: "keyboardLayout"

    readonly property bool shown: KeyboardService.indicatorVisible

    visible: shown
    contentLength: shown ? (vertical ? label.implicitHeight + 12 : row.implicitWidth + (flat ? 12 : 22)) : 0

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        objectName: "tap"
        onTapped: KeyboardService.next()
    }
    WheelHandler {
        objectName: "wheel"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!throttle.running) {
                KeyboardService.next();
                throttle.start();
            }
        }
    }
    Timer {
        id: throttle
        interval: 180
    }

    Row {
        id: row
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.keyboard
            font.family: Icons.font
            font.pixelSize: root.iconSize
            color: surface.foreground
            opacity: 0.8
        }
        Text {
            id: label
            objectName: "layoutLabel"
            anchors.verticalCenter: parent.verticalCenter
            text: KeyboardService.shortLabel
            font.family: Config.theme.font
            font.pixelSize: root.textSize
            font.weight: Font.Bold
            font.letterSpacing: 0.5
            color: surface.foreground
        }
    }

    Text {
        visible: root.vertical
        anchors.centerIn: parent
        text: KeyboardService.shortLabel
        font.family: Config.theme.font
        font.pixelSize: root.smallTextSize
        font.weight: Font.Bold
        color: surface.foreground
    }
}
