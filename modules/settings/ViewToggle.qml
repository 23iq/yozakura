pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
import qs.modules.services
import qs.modules.settings.store

// The settings chrome's Simple / All switch: off (Simple, the default)
// shows each page's essentials, on (All) every expert row too. The whole
// row toggles; the choice is remembered (general.settingsShowAll).
ListRow {
    id: root

    objectName: "viewToggle"
    title: I18n.t("prefs.view.all")
    subtitle: I18n.t(SettingsStore.showAll ? "prefs.view.all.desc" : "prefs.view.simple.desc")
    onClicked: SettingsStore.setShowAll(!SettingsStore.showAll)
    Accessible.role: Accessible.CheckBox
    Accessible.checked: SettingsStore.showAll

    trailing: Component {
        Switch {
            objectName: "viewToggleSwitch"
            checked: SettingsStore.showAll
            onToggled: v => SettingsStore.setShowAll(v)
        }
    }
}
