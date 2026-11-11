import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "NotchNotificationStyles.js" as NotchNotificationStyles
import "NotificationBody.js" as NotificationBody

Item {
    id: root

    implicitHeight: mainColumn.implicitHeight

    // Popups shown here: the notch presentation's list (Notifications.qml)
    property var popups: Notifications.notchPopupList
    property var currentNotification: {
        return (root.popups.length > currentIndex && currentIndex >= 0) ? root.popups[currentIndex] : (root.popups.length > 0 ? root.popups[0] : null);
    }
    property bool notchHovered: false
    property bool isNavigating: false
    property bool hovered: notchHovered || isNavigating

    // Índice actual para navegación
    property int currentIndex: 0
    // Contador para detectar cuando se añaden nuevas notificaciones
    property int lastNotificationCount: 0
    // Contador para forzar actualización del timestamp (incrementa cada minuto)
    property int timestampUpdateCounter: 0

    // Timer para forzar actualización del timestamp cada minuto
    // Solo corre cuando el componente es visible y hay notificaciones
    Timer {
        id: timestampUpdateTimer
        interval: 60000 // 1 minuto
        repeat: true
        running: root.visible && currentNotification !== null
        triggeredOnStart: false
        onTriggered: {
            // Incrementar contador para forzar re-evaluación del binding del timestamp
            root.timestampUpdateCounter++;
        }
    }

    // MouseArea para scroll y middle-click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.MiddleButton
        propagateComposedEvents: true
        z: 50

        // Navegación con rueda del ratón cuando hay múltiples notificaciones
        onWheel: wheel => {
            if (root.popups.length > 1) {
                if (wheel.angleDelta.y > 0) {
                    // Scroll hacia arriba - ir a la notificación anterior
                    navigateToPrevious();
                } else {
                    // Scroll hacia abajo - ir a la siguiente notificación
                    navigateToNext();
                }
            }
        }

        // Middle-click para descartar notificación
        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton && currentNotification) {
                if (root.popups.length > 1) {
                    root.isNavigating = true;
                    navigationHoverTimer.restart();
                }
                Notifications.discardNotification(currentNotification.id);
            }
            mouse.accepted = false;
        }
    }

    // Timer para mantener hover durante navegación
    Timer {
        id: navigationHoverTimer
        interval: Config.animDuration + 50
        repeat: false
        onTriggered: {
            root.isNavigating = false;
        }
    }

    // Funciones de navegación
    function navigateToNext() {
        if (root.popups.length > 1) {
            root.isNavigating = true;
            navigationHoverTimer.restart();
            const nextIndex = (currentIndex + 1) % root.popups.length;
            notificationStack.navigateToNotification(nextIndex);
        }
    }

    function navigateToPrevious() {
        if (root.popups.length > 1) {
            root.isNavigating = true;
            navigationHoverTimer.restart();
            const prevIndex = currentIndex > 0 ? currentIndex - 1 : root.popups.length - 1;
            notificationStack.navigateToNotification(prevIndex);
        }
    }

    function updateNotificationStack() {
        if (root.popups.length > 0 && notificationStack) {
            notificationStack.navigateToNotification(currentIndex);
        }
    }

    // Manejo del hover - pausa/reanuda timers de timeout de todas las notificaciones
    onHoveredChanged: {
        if (hovered) {
            // Pausar todos los timers de notificaciones activas
            Notifications.pauseAllTimers();
        } else {
            // Reanudar todos los timers de notificaciones activas
            Notifications.resumeAllTimers();
        }
    }

    // Sincronizar estado cuando el componente cambia de visibilidad
    onVisibleChanged: {
        if (visible && root.popups.length > 0) {
            // Ajustar índice si está fuera de rango
            if (currentIndex >= root.popups.length) {
                currentIndex = Math.max(0, root.popups.length - 1);
            }
            lastNotificationCount = root.popups.length;
            // Actualizar el stack si es necesario
            if (notificationStack.depth === 0) {
                notificationStack.push(notificationComponent, {
                    "notification": root.popups[currentIndex]
                });
            }
        } else if (!visible) {
            // Limpiar el stack cuando se oculta para evitar acumulación
            // Usar clear(StackView.Immediate) para evitar animaciones pendientes
            if (notificationStack.depth > 0) {
                notificationStack.clear(StackView.Immediate);
            }
            // Resetear contadores
            timestampUpdateCounter = 0;
        }
    }

    // The current notification follows hover and the minute tick
    Binding {
        target: notificationStack.currentItem
        property: "hovered"
        value: root.hovered
    }
    Binding {
        target: notificationStack.currentItem
        property: "timestampUpdateCounter"
        value: root.timestampUpdateCounter
    }
    // Not restored: a notification on its way out keeps its place ("2/3")
    Binding {
        target: notificationStack.currentItem
        property: "popups"
        value: root.popups
        restoreMode: Binding.RestoreNone
    }

    Column {
        id: mainColumn
        anchors.fill: parent
        spacing: 0

        // ÁREA DE CONTENIDO CON SCROLL: Combina contenido y botones de acción
        RowLayout {
            id: contentWithScrollArea
            width: parent.width
            implicitHeight: notificationStack.implicitHeight
            height: implicitHeight
            spacing: Space.s

            // Área principal de notificaciones (StackView)
            Item {
                id: notificationArea
                Layout.fillWidth: true
                Layout.preferredHeight: notificationStack.implicitHeight

                StackView {
                    id: notificationStack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    implicitHeight: currentItem ? currentItem.implicitHeight : 0
                    height: implicitHeight
                    clip: true

                    // Crear componente inicial
                    Component.onCompleted: {
                        if (root.popups.length > 0) {
                            push(notificationComponent, {
                                "notification": root.popups[0]
                            });
                        }
                    }

                    // Función para navegar a una notificación específica
                    function navigateToNotification(index, forceDirection = null) {
                        if (index >= 0 && index < root.popups.length) {
                            const newNotification = root.popups[index];
                            const currentItem = notificationStack.currentItem;

                            if (!currentItem || !currentItem.notification || currentItem.notification.id !== newNotification.id) {

                                // Determinar dirección de la transición
                                let direction;
                                if (forceDirection !== null) {
                                    direction = forceDirection;
                                } else {
                                    direction = index > root.currentIndex ? StackView.PushTransition : StackView.PopTransition;
                                }

                                // Usar replace para evitar acumulación en el stack
                                replace(notificationComponent, {
                                    "notification": newNotification
                                }, direction);

                                root.currentIndex = index;
                            }
                        }
                    }

                    // Actualizar cuando cambie la lista de notificaciones
                    // Solo activo cuando el componente es visible para evitar trabajo duplicado
                    Connections {
                        target: root.visible ? root : null
                        function onPopupsChanged() {
                            if (root.popups.length === 0) {
                                notificationStack.clear();
                                root.currentIndex = 0;
                                root.lastNotificationCount = 0;
                                return;
                            }

                            // Si no hay items en el stack, añadir la primera notificación
                            if (notificationStack.depth === 0) {
                                notificationStack.push(notificationComponent, {
                                    "notification": root.popups[0]
                                });
                                root.currentIndex = 0;
                                root.lastNotificationCount = root.popups.length;
                                return;
                            }

                            // Detectar nueva notificación: si la lista creció, ir a la más reciente (última)
                            // Solo si no hay hover para no interrumpir la interacción del usuario
                            if (root.popups.length > root.lastNotificationCount && !root.hovered) {
                                const newIndex = root.popups.length - 1;
                                root.currentIndex = newIndex;
                                notificationStack.navigateToNotification(newIndex, StackView.PushTransition);
                                root.lastNotificationCount = root.popups.length;
                                return;
                            }

                            // Actualizar el contador
                            root.lastNotificationCount = root.popups.length;

                            // Manejar eliminación de notificaciones
                            // Obtener la notificación actual antes del ajuste
                            const currentNotificationId = notificationStack.currentItem?.notification?.id;
                            const oldIndex = root.currentIndex;

                            // Ajustar el índice si es necesario
                            if (root.currentIndex >= root.popups.length) {
                                root.currentIndex = Math.max(0, root.popups.length - 1);
                            }

                            // Determinar si una notificación fue eliminada y calcular la dirección apropiada
                            const newNotification = root.popups[root.currentIndex];
                            let forceDirection = null;

                            // Si la notificación actual cambió, significa que se eliminó una
                            if (currentNotificationId && newNotification && currentNotificationId !== newNotification.id) {
                                // Si estábamos viendo una notificación posterior y ahora vemos una anterior,
                                // significa que se eliminó una notificación antes de la actual -> transición hacia abajo
                                if (oldIndex > 0 && root.currentIndex < oldIndex) {
                                    forceDirection = StackView.PopTransition; // Aparece desde arriba (hacia abajo)
                                } else
                                // Si se eliminó la notificación actual y vamos a la siguiente
                                if (root.currentIndex === oldIndex) {
                                    forceDirection = StackView.PushTransition; // Aparece desde abajo (hacia arriba)
                                }
                            }

                            // Navegar a la notificación actual con la dirección calculada
                            notificationStack.navigateToNotification(root.currentIndex, forceDirection);
                        }
                    }

                    // Transiciones verticales - igual que el launcher
                    pushEnter: Transition {
                        PropertyAnimation {
                            property: "y"
                            from: notificationStack.height
                            to: 0
                            duration: Config.animDuration
                            easing.type: Motion.enter.easing
                        }
                        PropertyAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Config.animDuration
                            easing.type: Motion.enter.easing
                        }
                    }

                    pushExit: Transition {
                        PropertyAnimation {
                            property: "y"
                            from: 0
                            to: -notificationStack.height
                            duration: Config.animDuration
                            easing.type: Motion.exit.easing
                        }
                        PropertyAnimation {
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: Config.animDuration
                            easing.type: Motion.exit.easing
                        }
                    }

                    popEnter: Transition {
                        PropertyAnimation {
                            property: "y"
                            from: -notificationStack.height
                            to: 0
                            duration: Config.animDuration
                            easing.type: Motion.enter.easing
                        }
                        PropertyAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Config.animDuration
                            easing.type: Motion.enter.easing
                        }
                    }

                    popExit: Transition {
                        PropertyAnimation {
                            property: "y"
                            from: 0
                            to: notificationStack.height
                            duration: Config.animDuration
                            easing.type: Motion.exit.easing
                        }
                        PropertyAnimation {
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: Config.animDuration
                            easing.type: Motion.exit.easing
                        }
                    }
                }

                // Componente de notificación reutilizable
                Component {
                    id: notificationComponent

                    Item {
                        id: slot
                        width: notificationStack.width
                        implicitHeight: styleLoader.implicitHeight

                        property var notification
                        // Fed by the view's Bindings on the current item
                        property bool hovered: false
                        property int timestampUpdateCounter: 0
                        property var popups: []
                        // Place among the popups ("2/3")
                        readonly property string position: NotificationBody.position(slot.popups.indexOf(slot.notification), slot.popups.length)

                        // notifications.notchStyle (NotchNotificationStyles.js)
                        Loader {
                            id: styleLoader
                            width: parent.width
                            sourceComponent: NotchNotificationStyles.isCompact(Config.notifications ? Config.notifications.notchStyle : "") ? compactStyle : cardStyle
                        }
                        Binding {
                            target: styleLoader.item
                            property: "notification"
                            value: slot.notification
                        }
                        Binding {
                            target: styleLoader.item
                            property: "hovered"
                            value: slot.hovered
                        }
                        Binding {
                            target: styleLoader.item
                            property: "timestampUpdateCounter"
                            value: slot.timestampUpdateCounter
                        }
                        Binding {
                            target: styleLoader.item
                            property: "position"
                            value: slot.position
                        }
                        Component {
                            id: cardStyle
                            NotchNotificationCard {}
                        }
                        Component {
                            id: compactStyle
                            CompactNotification {}
                        }
                    }
                }
            }
        }
    }
}
