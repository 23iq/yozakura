pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Home tile scene of System: the shell's version large, and chips for the
// interface language and the update state, read from the live services.
Item {
    id: scene

    required property Card tile
    readonly property string language: (I18n.availableLanguages || {})[I18n.resolvedLanguage] || ""

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Space.s
        KitText {
            width: parent.width
            role: "display"
            elide: Text.ElideRight
            text: UpdateService.currentVersion ? "v" + UpdateService.currentVersion : ""
        }
        Flow {
            width: parent.width
            spacing: Space.xs
            Chip {
                dense: true
                visible: scene.language !== ""
                icon: Icons.globe
                text: scene.language
            }
            Chip {
                dense: true
                icon: UpdateService.updateAvailable ? Icons.downloadSimple : Icons.accept
                text: I18n.t(UpdateService.updateAvailable ? "prefs.home.update" : "prefs.home.uptodate")
            }
        }
    }
}
