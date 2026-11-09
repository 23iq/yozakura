import QtQuick
import qs.modules.components.kit
import qs.modules.aicenter.common

// Text of the AI center: a kit type role (KitText) at the AI text scale
// (ai.appearance.fontScale, BarLook.size); `mono` sets it in the mono face.
//
//   AiText { role: "caption"; text: model.name }
KitText {
    id: root

    property bool mono: false

    font.family: root.mono ? Type.monoFont : Type.family(root.role)
    font.pixelSize: root.mono ? BarLook.monoSize(root.role) : BarLook.size(root.role)
}
