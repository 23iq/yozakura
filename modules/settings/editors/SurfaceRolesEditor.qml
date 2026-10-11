pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.editors.surfaces
import qs.modules.settings.store
import "surfaces/SurfaceRoles.js" as Roles
import "surfaces/RoleLocks.js" as RoleLocks

// Surface variants (theme.sr*: the styles every shell container is drawn
// with). Pick a role, edit its fill, opacity, border and item color; the
// fill style (linear / radial / halftone) and its knobs sit in a folded
// "More" block. Writes theme.<sr>.<field> through SettingsStore. Fields the
// current visual language rewrites (or Glass ignores) are dimmed and
// explained: see surfaces/RoleLocks.js.
ColumnLayout {
    id: root

    property var entry
    property string current: "srBg"

    readonly property var locks: RoleLocks.locks(Config.theme ? Config.theme.language : "", SettingsStore.get("theme.glass.enabled") !== false, current)
    readonly property var summary: RoleLocks.summary(locks)
    readonly property string langName: summary.language !== "" ? I18n.t("prefs.appearance.language." + summary.language) : ""
    readonly property string note: {
        if (summary.language !== "") {
            const names = summary.fields.map(f => I18n.t(Roles.fieldDef(f).label));
            return I18n.t("prefs.surfaces.lock.language", langName, names.join(", "));
        }
        const cap = locks.opacity;
        if (cap && cap.kind === "capped")
            return I18n.t("prefs.surfaces.lock.capped", I18n.t("prefs.appearance.language." + cap.language), Math.round(cap.value * 100));
        return summary.glass ? I18n.t("prefs.surfaces.lock.glass") : "";
    }

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

    KitText {
        objectName: "surfaceLockNote"
        Layout.fillWidth: true
        visible: root.note !== ""
        role: "caption"
        text: root.note
        wrapMode: Text.WordWrap
    }

    SurfaceFieldList {
        Layout.fillWidth: true
        prop: root.current
        group: "main"
        locks: root.locks
    }

    MoreDisclosure {
        Layout.fillWidth: true
        title: I18n.t("prefs.surfaces.more")
        hint: I18n.t("prefs.surfaces.more.hint")

        SurfaceFieldList {
            Layout.fillWidth: true
            prop: root.current
            group: "more"
            locks: root.locks
        }
    }
}
