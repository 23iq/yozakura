import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.theme

// Monitor multi-select: one chip per connected screen (name + resolution)
// plus "All screens" for the empty list. Names saved in the config but not
// connected now stay listed (dimmed hint) so they are not lost.
Item {
    id: root

    property var values: []
    property string allLabel: "prefs.common.all_screens"
    // Connected monitors (overridable for previews/tests)
    property var screens: Quickshell.screens || []
    readonly property var options: {
        const out = [];
        const seen = {};
        const screens = root.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s || !s.name || seen[s.name])
                continue;

            seen[s.name] = true;
            out.push({
                "value": s.name,
                "label": s.name,
                "icon": "monitor",
                "hint": s.width && s.height ? s.width + "×" + s.height : ""
            });
        }
        (root.values || []).forEach(n => {
            if (!seen[n])
                out.push({
                    "value": n,
                    "label": n,
                    "icon": "monitor",
                    "hint": I18n.t("prefs.common.disconnected")
                });
        });
        return out;
    }

    signal changed(var values)

    implicitWidth: chips.implicitWidth
    implicitHeight: chips.implicitHeight

    ChipsControl {
        id: chips

        width: parent.width
        options: root.options
        values: root.values
        allLabel: root.allLabel
        translate: false
        onChanged: v => {
            return root.changed(v);
        }
    }
}
