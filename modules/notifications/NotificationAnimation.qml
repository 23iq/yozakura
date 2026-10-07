import QtQuick
import qs.config
import qs.modules.theme

Item {
    id: root

    // Propiedades para la animación de destrucción
    property Item targetItem: null
    property real dismissOvershoot: 20
    property real parentWidth: 0
    property bool isDiscardAll: false

    // Señales para diferentes tipos de animación
    signal destroyFinished

    // Animación de destrucción
    ParallelAnimation {
        id: destroyAnimation
        running: false

        NumberAnimation {
            target: root.targetItem?.anchors
            property: "leftMargin"
            to: root.parentWidth / 8 + root.dismissOvershoot
            duration: Config.animDuration
            easing.type: Motion.emphasis.easing
            easing.overshoot: 1.1
        }

        NumberAnimation {
            target: root.targetItem
            property: "scale"
            from: 1.0
            to: 0.8
            duration: Config.animDuration
            easing.type: Motion.emphasis.easing
        }

        NumberAnimation {
            target: root.targetItem
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: Config.animDuration
            easing.type: Motion.emphasis.easing
        }

        onFinished: {
            root.destroyFinished();
        }
    }

    // Función pública para ejecutar animación de destrucción
    function startDestroy() {
        destroyAnimation.running = true;
    }
}
