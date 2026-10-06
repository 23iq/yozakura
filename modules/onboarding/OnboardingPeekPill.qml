import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.modules.globals
import qs.config

// Layer window for the peek pill: bottom-centre of the screen the wizard
// opened on, above the bar/dock reserved area. It never takes keyboard focus
// and reserves no space, so the real desktop stays fully usable. Loaded by
// shell.qml while OnboardingService.visible && peek.
PanelWindow {
    id: root

    property bool shown: false
    readonly property var reservation: Visibilities.reservations ? Visibilities.reservations[OnboardingService.screenName] : null
    readonly property int gap: 28

    screen: Quickshell.screens.find(s => s.name === OnboardingService.screenName) || Quickshell.screens[0] || null
    anchors.bottom: true
    WlrLayershell.margins.bottom: gap + (reservation ? reservation.bottomZone : 0)
    implicitWidth: pill.implicitWidth + 2 * gap
    implicitHeight: pill.implicitHeight + 2 * gap
    color: "transparent"
    // only the pill takes input; the transparent halo lets clicks through
    mask: Region {
        item: pill
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: Brand.namespace("onboarding-peek")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Component.onCompleted: Qt.callLater(() => root.shown = true)

    PeekPill {
        id: pill
        anchors.centerIn: parent
        shown: root.shown
    }
}
