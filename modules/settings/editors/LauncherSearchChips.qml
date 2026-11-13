pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import "../../widgets/launcher/Providers.js" as Providers

// What the launcher searches: one chip per provider (the inline results in
// their order, then the prefix tabs), lit while it is on; a click turns it
// on or off (prefix.launcher.disabled). The stage's results follow at once.
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property var disabled: SettingsStore.get("prefix.launcher.disabled") || []
    readonly property var ids: Providers.ordered(SettingsStore.get("prefix.launcher.order") || []).concat(Providers.TAB_IDS)

    implicitHeight: Math.max(root.fillHeight, flow.implicitHeight)

    Flow {
        id: flow
        width: root.width
        spacing: Space.s
        Repeater {
            model: root.ids
            delegate: Chip {
                id: chip
                required property string modelData
                readonly property bool on: Providers.isEnabled(modelData, root.disabled)
                objectName: "launcherSearch:" + modelData
                dense: true
                active: chip.on
                icon: Icons[(Providers.byId(modelData) || {}).icon] ?? ""
                text: I18n.t("launcher.provider." + modelData)
                Accessible.checked: chip.on
                onClicked: SettingsStore.set("prefix.launcher.disabled", Providers.setEnabled(root.disabled, chip.modelData, !chip.on))
            }
        }
    }
}
