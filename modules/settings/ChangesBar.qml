import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "Ui.js" as Ui

// Floating "unsaved changes" bar. Edits are already live (the shell
// previews them); Apply writes the config files, Discard restores the
// snapshot taken before the first edit.
Item {
    id: bar

    readonly property bool shown: SettingsStore.hasChanges

    implicitWidth: Math.min(row.implicitWidth + 36, parent ? parent.width - 32 : 600)
    implicitHeight: 56
    opacity: shown ? 1 : 0
    visible: opacity > 0
    transform: Translate {
        y: bar.shown ? 0 : 24
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
    }
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 1.5
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainerHighest
        border.width: 1
        border.color: Ui.alpha(Colors.primary, 0.35)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: Colors.primary
            SequentialAnimation on opacity {
                running: bar.shown && Config.animDuration > 0
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.35
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: I18n.t("common.unsaved_changes")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                text: I18n.t("prefs.changes.live")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
            }
        }
        Item {
            width: 6
            height: 1
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "discardButton"
            kind: "ghost"
            icon: "arrowCounterClockwise"
            text: I18n.t("prefs.changes.discard")
            onClicked: SettingsStore.discard()
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "applyButton"
            kind: "filled"
            icon: "accept"
            text: I18n.t("prefs.changes.apply")
            onClicked: SettingsStore.apply()
        }
    }
}
