pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.settings.store
import "SurfaceRoles.js" as Roles

// The fields of one group ("main" | "more") of the surface variant `prop`
// (Config.theme.<prop>). Every edit goes through SettingsStore with a
// dotted key ("theme.srBg.opacity"), so it is staged like any setting.
ColumnLayout {
    id: root

    property string prop: "srBg"
    property string group: "main"

    readonly property var role: Config.theme ? Config.theme[prop] : null
    readonly property var model: Roles.fields(role, group)

    spacing: 14

    function commit(field, value) {
        const ws = Roles.writes(root.role, field, value);
        for (let i = 0; i < ws.length; i++)
            SettingsStore.set("theme." + root.prop + "." + ws[i].sub, ws[i].value);
    }

    Repeater {
        model: root.model

        delegate: SurfaceField {
            required property var modelData
            Layout.fillWidth: true
            def: modelData
            value: Roles.read(root.role, modelData.field)
            onEdited: v => root.commit(modelData.field, v)
        }
    }
}
