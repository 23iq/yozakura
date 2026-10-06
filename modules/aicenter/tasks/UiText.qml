import QtQuick
import qs.modules.theme
import qs.config
import qs.modules.aicenter.common

// Text of the task views: theme font scaled by the AI bar text size
// (`size` is a Styling offset), muted/mono/strong variants.
Text {
    property int size: -1
    property bool muted: false
    property bool mono: false
    property bool strong: false

    font.family: mono ? Config.theme.monoFont : Config.theme.font
    font.pixelSize: mono ? BarLook.mono(size) : BarLook.font(size)
    font.weight: strong ? Font.DemiBold : Font.Normal
    color: muted ? Colors.outline : Colors.overSurface
    elide: Text.ElideRight
}
