import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.presets.store

// "Try the new Yozakura look", once, for existing users (PresetNewLook,
// NewLookFlow.js). Try previews it with a 30 s Keep / Revert countdown;
// Not now dismisses it for good. Hidden when there is nothing to offer.
Group {
    id: root

    readonly property string phase: PresetNewLook.phase
    readonly property bool trying: PresetNewLook.trying

    objectName: "tryNewLook"
    visible: PresetNewLook.offer
    label: I18n.t("presets.newlook.label")

    KitText {
        width: parent.width
        role: "title"
        text: I18n.t("presets.newlook.title")
    }

    KitText {
        objectName: "newLookText"
        width: parent.width
        role: "secondary"
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        text: root.trying ? I18n.t("presets.newlook.countdown", PresetNewLook.left) : I18n.t("presets.newlook.desc")
    }

    ProgressLine {
        width: parent.width
        visible: root.phase === "trying"
        value: PresetNewLook.fraction
    }

    Row {
        spacing: Space.s

        Chip {
            objectName: "newLookTry"
            visible: !root.trying
            active: true
            icon: Icons.sparkle
            text: I18n.t("presets.newlook.try")
            onClicked: PresetNewLook.tryIt()
        }

        Chip {
            objectName: "newLookNotNow"
            visible: !root.trying
            text: I18n.t("presets.newlook.not_now")
            onClicked: PresetNewLook.dismiss()
        }

        Chip {
            objectName: "newLookKeep"
            visible: root.trying
            enabled: root.phase === "trying"
            active: true
            icon: Icons.check
            text: I18n.t("presets.newlook.keep")
            onClicked: PresetNewLook.keep()
        }

        Chip {
            objectName: "newLookRevert"
            visible: root.trying
            enabled: root.phase === "trying"
            icon: Icons.arrowCounterClockwise
            text: I18n.t("presets.newlook.revert")
            onClicked: PresetNewLook.revert()
        }
    }
}
