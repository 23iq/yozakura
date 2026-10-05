import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store

// A button that opens another settings page (entry.target) at a section
// (entry.targetSection), labelled entry.linkText.
Item {
    id: root

    property var entry

    implicitHeight: 34

    PillButton {
        icon: "arrowSquareOut"
        kind: "ghost"
        text: I18n.t(root.entry && root.entry.linkText ? root.entry.linkText : "prefs.common.open_classic")
        onClicked: SettingsStore.navigate(root.entry ? root.entry.target : "", root.entry ? (root.entry.targetSection || "") : "", "")
    }
}
