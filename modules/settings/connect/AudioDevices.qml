import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.services

// Sound > the outputs (entry.output: true) or the inputs: every device
// with the one in use lit; a click makes it the one in use. The one in use
// has no volume line here (the band's big slider is its volume); the
// others keep a small one.
DeviceList {
    id: root

    property var entry
    readonly property bool output: !!root.entry && root.entry.output === true
    readonly property var nodes: (root.output ? Audio.outputDevices : Audio.inputDevices) || []
    readonly property var inUse: root.output ? (Audio.sink ?? null) : (Audio.source ?? null)

    objectName: root.output ? "outputDevices" : "inputDevices"
    current: root.inUse ? String(root.inUse.id) : ""
    empty: I18n.t("prefs.sound.no_device")
    rows: root.nodes.map(n => ({
                "key": String(n.id),
                "icon": root.output ? (/hdmi|displayport/i.test(String(n.description || n.name)) ? "monitor" : /head/i.test(String(n.description || n.name)) ? "headphones" : "speakerHigh") : (/head/i.test(String(n.description || n.name)) ? "headphones" : "mic"),
                "title": Audio.friendlyDeviceName(n),
                "line": root.inUse && n.id === root.inUse.id ? I18n.t("prefs.sound.in_use") : "",
                "on": !!root.inUse && n.id === root.inUse.id,
                "trailing": "",
                "volume": n.audio && !(root.inUse && n.id === root.inUse.id) ? Number(n.audio.volume ?? -1) : -1
            }))
    // device volumes report only while tracked
    PwObjectTracker {
        objects: root.nodes
    }
    onVolumeMoved: (key, v) => {
        const n = root.nodes.find(x => String(x.id) === key);
        if (n)
            Audio.setNodeVolume(n, v);
    }
    onPicked: key => {
        const n = root.nodes.find(x => String(x.id) === key);
        if (!n)
            return;
        if (root.output)
            Audio.setDefaultSink(n);
        else
            Audio.setDefaultSource(n);
    }
}
