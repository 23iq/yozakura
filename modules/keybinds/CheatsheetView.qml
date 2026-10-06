import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.modules.settings.store
import qs.modules.keybinds

// The cheatsheet as a hostable view (layout.cheatsheet.host): the panel
// plus its close/edit actions. The fullscreen host (CheatsheetWindow) and the
// spotlight/sheet hosts (modules/shell/hosts) all show this.
FocusScope {
    id: root

    property string screenName: ""

    // Spotlight sizing: wide enough for three columns.
    implicitWidth: Math.round(Metrics.sheetW * 2.6)
    implicitHeight: Math.round(Metrics.sheetW * 1.6)

    function close() {
        if (Visibilities.currentActiveModule === "keybinds")
            Visibilities.setActiveModule("");
    }

    function edit(uid) {
        KeybindsStore.requestEdit(uid);
        const row = KeybindsStore.row(uid);
        GlobalStates.settingsCategory = "input";
        if (GlobalStates.settingsWindowVisible)
            SettingsStore.navigate("input", row ? row.group : "", "");
        else
            GlobalShortcuts.toggleSettings();
        root.close();
    }

    onActiveFocusChanged: {
        if (activeFocus)
            panel.focusSearch();
    }
    Component.onCompleted: KeybindsStore.refreshNative()

    CheatsheetPanel {
        id: panel
        objectName: "cheatsheetPanel"
        anchors.fill: parent
        onCloseRequested: root.close()
        onEditRequested: uid => root.edit(uid)
    }
}
