import QtQuick
import qs.config
import qs.modules.theme

// Comportamiento estándar para animaciones de elementos que aparecen en el notch
Item {
    id: root

    // Propiedad para controlar la visibilidad con animaciones
    property bool isVisible: false

    // Aplicar las animaciones estándar del notch
    scale: isVisible ? 1.0 : 0.8
    opacity: isVisible ? 1.0 : 0.0
    visible: opacity > 0

    Behavior on scale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
            easing.overshoot: 1.2
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.enter.easing
        }
    }
}
