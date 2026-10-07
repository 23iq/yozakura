import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.bar.look

// Pin/unpin toggle for the bar's auto-hide. `barRoot` is BarContent.
Button {
    id: pinButton

    required property var barRoot
    property bool vertical: false
    property bool enableShadow: true
    property real startRadius: 0
    property real endRadius: 0
    // Bar panels: module size; Button.flat drops the pill background
    property int moduleSize: BarMetrics.moduleSize

    implicitWidth: moduleSize
    implicitHeight: moduleSize

    // Pinned is the active (accent) state of the module
    background: ModuleBox {
        id: pinButtonBg
        vertical: pinButton.vertical
        startRadius: pinButton.startRadius
        endRadius: pinButton.endRadius
        flat: pinButton.flat
        shadow: pinButton.enableShadow
        active: pinButton.barRoot.pinned
        hovered: pinButton.hovered || pinButton.pressed
    }

    contentItem: Text {
        text: Icons.pin
        font.family: Icons.font
        font.pixelSize: BarLook.iconSize(pinButton.moduleSize)
        color: pinButtonBg.ink
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        rotation: pinButton.barRoot.pinned ? 0 : 45
        Behavior on rotation {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
            NumberAnimation {
                duration: Motion.exit.duration
            }
        }

        Behavior on color {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
            ColorAnimation {
                duration: Motion.exit.duration
            }
        }
    }

    onClicked: barRoot.togglePin()

    StyledToolTip {
        show: pinButton.hovered
        tooltipText: pinButton.barRoot.pinned ? I18n.t("bar.tooltip.unpin_bar") : I18n.t("bar.tooltip.pin_bar")
    }
}
