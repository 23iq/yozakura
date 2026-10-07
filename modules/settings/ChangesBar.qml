import QtQuick
import qs.modules.services
import qs.config
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.theme

// Floating "unsaved changes" bar. Edits are already live (the shell
// previews them); Apply writes the config files, Discard restores the
// snapshot taken before the first edit.
Item {
    id: bar

    readonly property bool shown: SettingsStore.hasChanges

    implicitWidth: Math.min(row.implicitWidth + Space.l * 2, parent ? parent.width - Space.xxl : 600)
    implicitHeight: Space.controlL
    opacity: shown ? 1 : 0
    visible: opacity > 0
    transform: Translate {
        y: bar.shown ? 0 : 24
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Motion.morph.easing
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

    Surface {
        anchors.fill: parent
        padding: 0
        radius: Look.chipRadius(height) > 0 ? height / 2 : 0
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Space.m

        Column {
            anchors.verticalCenter: parent.verticalCenter
            KitText {
                role: "body"
                text: I18n.t("common.unsaved_changes")
            }
            KitText {
                role: "caption"
                text: I18n.t("prefs.changes.live")
            }
        }
        Item {
            width: Space.s
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
