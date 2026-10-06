import QtQuick
import qs.modules.theme
import qs.modules.aicenter.common

// An icon-font glyph sized like the AI bar text; `role` is a Colors role.
Text {
    property string role: "overSurface"
    property int size: -1

    font.family: Icons.font
    font.pixelSize: BarLook.font(size)
    color: Colors[role] !== undefined ? Colors[role] : Colors.overSurface
}
