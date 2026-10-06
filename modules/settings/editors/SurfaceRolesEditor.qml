pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.settings.editors.surfaces
import "surfaces/SurfaceRoles.js" as Roles

// Surface variants (theme.sr*: the styles every shell container is drawn
// with). Pick a role, edit its fill, opacity, border and item color; the
// fill style (linear / radial / halftone) and its knobs sit in a folded
// "More" block. Writes theme.<sr>.<field> through SettingsStore.
ColumnLayout {
    id: root

    property var entry
    property string current: "srBg"

    readonly property string currentLabel: {
        const all = Roles.roles();
        for (let i = 0; i < all.length; i++) {
            if (all[i].prop === current)
                return I18n.t(all[i].label);
        }
        return current;
    }

    spacing: 16

    RolePicker {
        Layout.fillWidth: true
        current: root.current
        onPicked: p => root.current = p
    }

    RolePreview {
        Layout.fillWidth: true
        prop: root.current
        label: root.currentLabel
    }

    SurfaceFieldList {
        Layout.fillWidth: true
        prop: root.current
        group: "main"
    }

    MoreDisclosure {
        Layout.fillWidth: true
        title: I18n.t("prefs.surfaces.more")
        hint: I18n.t("prefs.surfaces.more.hint")

        SurfaceFieldList {
            Layout.fillWidth: true
            prop: root.current
            group: "more"
        }
    }
}
