import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.components

// Pill background of a file-based module: honours the panel's flat mode,
// the group radii and an active (popup open) state; hover tint on top.
StyledRect {
    id: surface

    required property var module
    property bool active: false
    property bool hovered: false

    // Foreground for content drawn on the surface
    readonly property color foreground: active ? item : Colors.overBackground

    variant: active ? "primary" : "bg"
    anchors.fill: parent
    enableShadow: module.enableShadow && !module.flat
    backgroundOpacity: module.flat && !active ? 0 : -1
    effectSurface: module.flat || active ? "" : "bar"
    enableBorder: !module.flat || active

    topLeftRadius: module.startRadius
    topRightRadius: module.vertical ? module.startRadius : module.endRadius
    bottomLeftRadius: module.vertical ? module.endRadius : module.startRadius
    bottomRightRadius: module.endRadius

    Rectangle {
        anchors.fill: parent
        color: surface.module.flat ? Colors.overBackground : Styling.srItem("overprimary")
        opacity: surface.active ? 0 : (surface.hovered ? (surface.module.flat ? 0.08 : 0.25) : 0)
        radius: surface.module.flat ? Math.min(surface.height, surface.width) / 4 : (parent.radius ?? 0)

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
            }
        }
    }
}
