import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.modules.widgets.powermenu.styles as Styles

// The notch's power menu view (layout.powermenu.style "notch"); the other
// styles open in the menu overlay (modules/widgets/menus/MenuOverlay.qml).
Item {
    implicitWidth: powerMenu.implicitWidth
    implicitHeight: powerMenu.implicitHeight

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

    Styles.Notch {
        id: powerMenu
        anchors.fill: parent
        onCloseRequested: Visibilities.setActiveModule("")
    }

    // Take focus whenever the StackView shows this view
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => powerMenu.forceActiveFocus());
    }

    Component.onCompleted: {
        if (visible)
            Qt.callLater(() => powerMenu.forceActiveFocus());
    }
}
