pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// What a new terminal greets you with: "Off" or one of the fastfetch looks
// (TerminalLookService.fetchPresets), one chip each, the current one lit.
// A look turns the greeting on with it (one undo step) and queues fastfetch
// when it is missing; the stage's terminal shows it. The logo and the
// shells it runs in are in the full editor ("More").
Item {
    id: root

    property var entry
    property real fillHeight: 0
    readonly property bool on: SettingsStore.get("terminal.greeting") === "fastfetch"
    readonly property string preset: String(SettingsStore.get("terminal.fastfetchPreset") || "")

    implicitHeight: Math.max(root.fillHeight, flow.implicitHeight)

    function pick(id) {
        if (id === "") {
            SettingsStore.set("terminal.greeting", "none");
            return;
        }
        TerminalLookService.allowGreetingShells();
        SettingsStore.transaction("prefs.term.section.greeting", () => {
            SettingsStore.set("terminal.fastfetchPreset", id);
            SettingsStore.set("terminal.greeting", "fastfetch");
        });
        if (!TerminalLookService.fastfetchInstalled)
            TerminalLookService.installFastfetch();
    }

    Flow {
        id: flow
        width: root.width
        spacing: Space.s
        Repeater {
            model: [{
                    "id": "",
                    "name": I18n.t("prefs.common.off")
                }].concat((TerminalLookService.fetchPresets || []).map(p => ({
                        "id": p.id,
                        "name": p.own ? I18n.t("term.fetch.preset.own") : p.name
                    })))
            delegate: Chip {
                id: chip
                required property var modelData
                objectName: "greeting:" + (modelData.id || "off")
                dense: true
                active: modelData.id === "" ? !root.on : (root.on && root.preset === modelData.id)
                icon: modelData.id === "" ? Icons.minus : Icons.terminal
                text: modelData.name
                onClicked: root.pick(chip.modelData.id)
            }
        }
    }
}
