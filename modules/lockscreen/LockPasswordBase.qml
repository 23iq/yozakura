import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.config
import qs.modules.theme

// Logic shared by every style's password field. Authentication lives in
// LockScreen.qml: it reads `field.text` on `field.accepted`, drives
// `authenticating`/`showError` and plays the wrong-password animation
// through this interface. A style only provides the visuals and sets
// `field` to its TextField.
Item {
    id: root

    // Set by LockView.
    property LockView view: null
    // The style's TextField.
    property TextField field: null
    property bool showError: false
    property real shakeOffset: 0
    // Shake strength (0 = no shake, the error state still shows).
    property real shakeAmplitude: 1

    readonly property bool authenticating: view ? view.authenticating : false
    readonly property string errorMessage: view ? view.errorMessage : ""
    readonly property int failLockSecondsLeft: view ? view.failLockSecondsLeft : 0
    readonly property bool capsLock: view ? view.capsLock : false
    readonly property bool hasText: field !== null && field.text.length > 0
    readonly property bool errorShown: showError || (errorMessage !== "" && !hasText) || failLockSecondsLeft > 0

    // Emitted when the shake finishes; LockScreen clears the field there.
    signal wrongPasswordFinished
    // Caps Lock was pressed/released; LockScreen re-reads the LED state.
    signal capsLockToggled

    function playWrongPassword() {
        wrongPasswordAnim.restart();
    }

    // Wire to the TextField's Keys.onReleased: observes only, never
    // consumes keys, so typing and Enter behave as usual.
    function observeKey(event) {
        if (event.key === Qt.Key_CapsLock)
            capsLockToggled();
        event.accepted = false;
    }

    readonly property string hint: {
        if (failLockSecondsLeft > 0)
            return I18n.t("lockscreen.locked_out", failLockSecondsLeft);
        if (showError || (errorMessage !== "" && !hasText))
            return I18n.t("lockscreen.wrong_password");
        if (authenticating)
            return I18n.t("lockscreen.authenticating");
        if (capsLock)
            return I18n.t("lockscreen.caps_lock");
        return "";
    }

    SequentialAnimation {
        id: wrongPasswordAnim
        ScriptAction {
            script: root.showError = true
        }
        NumberAnimation {
            target: root
            property: "shakeOffset"
            to: 14 * root.shakeAmplitude
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: root
            property: "shakeOffset"
            to: -12 * root.shakeAmplitude
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: root
            property: "shakeOffset"
            to: 9 * root.shakeAmplitude
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: root
            property: "shakeOffset"
            to: -5 * root.shakeAmplitude
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
        NumberAnimation {
            target: root
            property: "shakeOffset"
            to: 0
            duration: Motion.emphasis.duration
            easing.type: Motion.emphasis.easing
        }
        ScriptAction {
            script: root.wrongPasswordFinished()
        }
    }
}
