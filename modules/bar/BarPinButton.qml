import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

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

    background: StyledRect {
        id: pinButtonBg
        variant: pinButton.barRoot.pinned ? "primary" : "bg"
        enableShadow: pinButton.enableShadow && !pinButton.flat
        backgroundOpacity: pinButton.flat && !pinButton.barRoot.pinned ? 0 : -1
        effectSurface: pinButton.flat ? "" : "bar"
        enableBorder: !pinButton.flat || pinButton.barRoot.pinned

        topLeftRadius: pinButton.startRadius
        topRightRadius: pinButton.vertical ? pinButton.startRadius : pinButton.endRadius
        bottomLeftRadius: pinButton.vertical ? pinButton.endRadius : pinButton.startRadius
        bottomRightRadius: pinButton.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: pinButton.barRoot.pinned ? 0 : (pinButton.pressed ? 0.5 : (pinButton.hovered ? 0.25 : 0))
            radius: (parent.radius !== undefined ? parent.radius : 0)

            Behavior on opacity {
                enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                NumberAnimation {
                    duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                }
            }
        }
    }

    contentItem: Text {
        text: Icons.pin
        font.family: Icons.font
        font.pixelSize: BarMetrics.iconFor(18, pinButton.moduleSize)
        color: pinButton.barRoot.pinned ? pinButtonBg.item : (pinButton.pressed ? Colors.background : (Styling.srItem("overprimary") || Colors.overBackground))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        rotation: pinButton.barRoot.pinned ? 0 : 45
        Behavior on rotation {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
            NumberAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
            }
        }

        Behavior on color {
            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
            ColorAnimation {
                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
            }
        }
    }

    onClicked: barRoot.togglePin()

    StyledToolTip {
        show: pinButton.hovered
        tooltipText: pinButton.barRoot.pinned ? I18n.t("bar.tooltip.unpin_bar") : I18n.t("bar.tooltip.pin_bar")
    }
}
