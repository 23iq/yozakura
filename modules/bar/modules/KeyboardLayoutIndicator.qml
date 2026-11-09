import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.look

// Active keyboard layout (EN, RU...). Click switches to the next layout, the
// wheel cycles. Hidden unless more than one layout is configured and
// keyboard.showIndicator is on.
BarModuleBase {
    id: root

    moduleKey: "keyboardLayout"

    readonly property bool shown: KeyboardService.indicatorVisible

    visible: shown
    contentLength: shown ? (vertical ? label.implicitHeight + Space.m : row.implicitWidth + (flat ? Space.m : Space.xl)) : 0

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
        spacing: Space.xs
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.keyboard
            size: root.iconSize
            color: surface.foreground
            opacity: 0.8
        }
        KitText {
            id: label
            objectName: "layoutLabel"
            anchors.verticalCenter: parent.verticalCenter
            role: BarLook.textRole(root.moduleSize)
            text: KeyboardService.shortLabel
            font.weight: Look.activeLabelWeight
            color: surface.foreground
        }
    }

    KitText {
        visible: root.vertical
        anchors.centerIn: parent
        role: "caption"
        text: KeyboardService.shortLabel
        font.weight: Look.activeLabelWeight
        color: surface.foreground
    }
}
