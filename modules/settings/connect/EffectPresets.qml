import QtQuick
import qs.modules.services

// Effects > the EasyEffects presets for what you hear (entry.output:
// true) or for the microphone, the running one lit; a click loads it.
DeviceList {
    id: root

    property var entry
    readonly property bool output: !!root.entry && root.entry.output === true
    readonly property var presets: (root.output ? EasyEffectsService.outputPresets : EasyEffectsService.inputPresets) || []
    readonly property string active: String((root.output ? EasyEffectsService.activeOutputPreset : EasyEffectsService.activeInputPreset) || "")

    stretch: true
    objectName: root.output ? "outputPresets" : "inputPresets"
    current: root.active
    empty: I18n.t(EasyEffectsService.available ? "prefs.effects.no_presets" : "prefs.effects.missing")
    rows: root.presets.map(p => ({
                "key": String(p),
                "icon": root.output ? "faders" : "mic",
                "title": String(p),
                "line": String(p) === root.active ? I18n.t("prefs.effects.running") : "",
                "on": String(p) === root.active,
                "trailing": ""
            }))
    onPicked: key => {
        if (root.output)
            EasyEffectsService.loadOutputPreset(key);
        else
            EasyEffectsService.loadInputPreset(key);
    }
}
