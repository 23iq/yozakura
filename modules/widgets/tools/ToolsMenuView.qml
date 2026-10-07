import QtQuick
import qs.modules.components
import qs.modules.services
import qs.modules.theme

Item {
    implicitWidth: toolsMenu.implicitWidth
    implicitHeight: toolsMenu.implicitHeight

    Behavior on implicitWidth {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    Behavior on implicitHeight {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    ToolsMenu {
        id: toolsMenu
        anchors.fill: parent
        
        onItemSelected: {
            Visibilities.setActiveModule("")
        }
    }
    
    // Forzar foco cuando aparece la vista en el StackView
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(() => {
                toolsMenu.forceActiveFocus();
            });
        }
    }
    
    Component.onCompleted: {
        if (visible) {
            Qt.callLater(() => {
                toolsMenu.forceActiveFocus();
            });
        }
    }
}
