import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store
import "../Ui.js" as Ui

// Opens a classic panel category (entry.target) for options that are not
// migrated to this page yet.
Item {
    id: root

    property var entry

    implicitHeight: 34

    PillButton {
        icon: "arrowSquareOut"
        kind: "ghost"
        text: I18n.t("prefs.common.open_classic")
        onClicked: SettingsStore.navigate(root.entry ? root.entry.target : "", "", "")
    }
}
