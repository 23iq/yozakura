import QtQuick
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
import qs.modules.theme

// Kitty's background opacity is the glass "terminal" surface: shows the
// effective value written to kitty.conf and jumps to the per-surface glass
// settings (Appearance > Glass per surface).
Item {
    id: root

    property var entry
    readonly property real effective: Glass.terminalOpacity
    readonly property real surfaceAmount: Number(SettingsStore.get("theme.glass.surfaces.terminal.amount") ?? -1)
    readonly property bool glassOn: !!SettingsStore.get("theme.glass.enabled")

    implicitHeight: line.implicitHeight

    StatusLine {
        id: line

        width: parent.width
        icon: "drop"
        tone: root.glassOn ? "ok" : "muted"
        title: I18n.t("prefs.term.glass.effective", Math.round(root.effective * 100) + "%")
        detail: !root.glassOn ? I18n.t("prefs.term.glass.off") : (root.surfaceAmount < 0 ? I18n.t("prefs.term.glass.inherit") : I18n.t("prefs.term.glass.amount", Math.round(root.surfaceAmount * 100) + "%"))

        PillButton {
            objectName: "glassLink"
            kind: "ghost"
            icon: "arrowSquareOut"
            text: I18n.t("prefs.term.glass.open")
            onClicked: SettingsStore.navigate("appearance", "glassSurfaces", "theme.glass.surfaces")
        }
    }
}
