import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "../Ui.js" as Ui
import qs.modules.components.kit

// Shown on every settings page while a user preset is being edited: the
// preset is applied, so every page edits it live; Save writes the live
// config into the preset and brings the previous look back ("Save & use"
// keeps the preset applied), Discard drops the edits.
Rectangle {
    id: banner

    readonly property bool shown: PresetStudio.edit !== null
    readonly property string preset: PresetStudio.edit ? PresetStudio.edit.preset : ""

    objectName: "presetEditBanner"
    implicitHeight: shown ? row.implicitHeight + 20 : 0
    height: implicitHeight
    visible: shown
    clip: true
    color: Ui.mix(Colors.surfaceContainerHigh, Colors.primary, 0.14)
    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Ui.alpha(Colors.primary, 0.4)
    }

    Item {
        id: row
        x: 20
        y: 10
        width: parent.width - 40
        implicitHeight: Math.max(textCol.implicitHeight, buttons.implicitHeight)

        Icon {
            id: icon
            tone: "accent"
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.pencil
        }
        Column {
            id: textCol
            anchors.left: icon.right
            anchors.leftMargin: Space.m
            anchors.right: buttons.left
            anchors.rightMargin: Space.m
            anchors.verticalCenter: parent.verticalCenter
            KitText {
                role: "secondary"
                width: parent.width
                text: I18n.t("prefs.presets.editing", banner.preset)
                font.weight: Font.Bold
                color: Colors.overBackground
                elide: Text.ElideRight
            }
            KitText {
                role: "caption"
                width: parent.width
                text: I18n.t("prefs.presets.editing.desc")
                color: Colors.overSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            PillButton {
                objectName: "editDiscard"
                kind: "ghost"
                icon: "arrowCounterClockwise"
                text: I18n.t("prefs.presets.edit.discard")
                onClicked: PresetStudio.finishEdit(false, false)
            }
            PillButton {
                objectName: "editSaveKeep"
                kind: "tonal"
                icon: "checkCircle"
                text: I18n.t("prefs.presets.edit.save_use")
                onClicked: PresetStudio.finishEdit(true, true)
            }
            PillButton {
                objectName: "editSave"
                kind: "filled"
                icon: "accept"
                text: I18n.t("prefs.presets.edit.save")
                onClicked: PresetStudio.finishEdit(true, false)
            }
        }
    }
}
