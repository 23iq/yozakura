import QtQuick
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.editors

// Problems of the Keyboard page the user can act on: the compositor's
// settings could not be read (Retry), or the live compositor refused the
// saved config (Apply again). The first one blocks editing, so it wins.
Column {
    id: root

    readonly property bool readFailed: KeyboardService.readFailed
    readonly property bool applyFailed: !readFailed && KeyboardService.applyError !== "" && KeyboardService.managed

    visible: readFailed || applyFailed
    spacing: 0

    StatusLine {
        objectName: "keyboardProblem"
        width: parent.width
        icon: "warning"
        tone: "error"
        title: I18n.t(root.readFailed ? "prefs.keyboard.read_failed" : "prefs.keyboard.apply_failed")
        detail: root.readFailed ? KeyboardService.readError : KeyboardService.applyError

        PillButton {
            objectName: "keyboardRetry"
            kind: "ghost"
            icon: "arrowsClockwise"
            text: I18n.t(root.readFailed ? "prefs.keyboard.retry" : "prefs.keyboard.apply_again")
            onClicked: root.readFailed ? KeyboardService.retryRead() : KeyboardService.apply()
        }
    }
}
