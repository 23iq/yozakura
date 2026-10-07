import QtQuick
import qs.modules.bar.look

// Box of a file-based module (BarModuleBase): its piece of the group box,
// hover and the active (popup open) accent state, see look/ModuleBox.qml.
// `foreground` is the ink for content drawn on it.
ModuleBox {
    id: surface

    required property var module

    readonly property color foreground: surface.ink

    vertical: module.vertical
    startRadius: module.startRadius
    endRadius: module.endRadius
    flat: module.flat
    shadow: module.enableShadow
}
