import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit

// Main shell, performance.separateWindows: "Opening Settings..." while the
// daemon starts the Settings (or setup wizard) process and until its window
// is shown, so the key press or click answers at once. shell.qml loads it
// by URL only while SeparateWindows.*Opening; it gives up after a while (a
// window that never reports itself shown). Never takes input or focus.
PanelWindow {
    id: root

    readonly property bool wizard: SeparateWindows.wizardOpening && !SeparateWindows.settingsOpening
    readonly property string screenName: root.wizard ? OnboardingService.screenName : GlobalStates.settingsTargetScreenName
    property bool shown: false
    property bool expired: false

    screen: Quickshell.screens.find(s => s.name === root.screenName) || Quickshell.screens[0] || null
    anchors.bottom: true
    WlrLayershell.margins.bottom: Space.xxl
    implicitWidth: pill.implicitWidth + 2 * Space.xl
    implicitHeight: pill.implicitHeight + 2 * Space.xl
    color: "transparent"
    mask: Region {}
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: Brand.namespace("window-opening")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: !root.expired

    Component.onCompleted: Qt.callLater(() => root.shown = true)

    Timer {
        interval: 20000
        running: true
        onTriggered: root.expired = true
    }

    Surface {
        id: pill
        objectName: "openingPill"
        anchors.centerIn: parent
        floating: true
        padding: Space.s
        radius: Look.bigRadius(height)
        opacity: root.shown ? 1 : 0
        Behavior on opacity {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }

        Row {
            spacing: Space.m
            leftPadding: Space.xs
            rightPadding: Space.s

            Icon {
                id: spinner
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.circleNotch
                role: "body"
                tone: "accent"
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: root.visible
                }
            }
            KitText {
                objectName: "openingLabel"
                anchors.verticalCenter: parent.verticalCenter
                role: "body"
                text: I18n.t(root.wizard ? "onboarding.window.opening" : "prefs.window.opening")
            }
        }
    }
}
