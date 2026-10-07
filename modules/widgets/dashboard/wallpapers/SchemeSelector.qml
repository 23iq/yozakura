import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.globals
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "SchemeOptions.js" as SchemeOptions

// The wallpapers tab's colour scheme: a kit Dropdown of the matugen schemes
// and the colour presets (its popup scrolls and floats above the grid) plus a
// light/dark button. Tab / Shift+Tab / Escape hand focus back to the tab.
RowLayout {
    id: root

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var options: SchemeOptions.options(root.manager ? root.manager.colorPresets : [], key => I18n.t(key))

    signal schemeSelectorClosed
    signal escapePressedOnScheme
    signal tabPressed
    signal shiftTabPressed

    function openAndFocus() {
        dropdown.forceActiveFocus();
    }

    function pick(value) {
        const v = SchemeOptions.parse(value);
        if (!v || !root.manager)
            return;
        if (v.kind === "preset")
            root.manager.setColorPreset(v.id);
        else
            root.manager.setMatugenScheme(v.id);
    }

    spacing: Space.s
    implicitHeight: Space.chip

    Dropdown {
        id: dropdown
        Layout.fillWidth: true
        options: root.options
        value: root.manager ? SchemeOptions.current(root.manager.activeColorPreset, root.manager.currentMatugenScheme) : ""
        onSelected: value => root.pick(value)

        Keys.onTabPressed: root.tabPressed()
        Keys.onBacktabPressed: root.shiftTabPressed()
        Keys.onEscapePressed: {
            dropdown.focus = false;
            root.escapePressedOnScheme();
        }
    }

    IconButton {
        icon: Config.theme.lightMode ? Icons.sun : Icons.moon
        active: Config.theme.lightMode
        onClicked: Config.theme.lightMode = !Config.theme.lightMode
    }
}
