import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "../stages/LauncherSamples.js" as Samples

// Card picture of a launcher result style (layout.launcher.resultStyle):
// the real launcher (live/LiveHosted, LauncherView) in your host's frame
// with the stage's sample search in style `value` (list, cards, or the app
// grid of an empty search). Pictured once, again when the look changes.
MiniScreen {
    id: root

    property var entry
    property var value: "list"
    readonly property string style: String(root.value)
    readonly property var appNames: (AppSearch.getAllApps ? AppSearch.getAllApps() : []).slice(0, 8).map(a => a.name)
    readonly property string query: Samples.query(root.appNames, root.style)
    // pictured again when what it shows changes
    readonly property var look: [SettingsStore.get("layout.launcher.icons"), SettingsStore.get("prefix.launcher.order"), SettingsStore.get("prefix.launcher.disabled"), String(Colors.primary), String(Colors.background), Look.language]

    LiveHosted {
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 2)
        surface: "launcher"
        // a picture: the launcher's top-left corner (its search and first
        // results in the style), at a size where it reads
        host: "spotlight"
        margin: 0
        minZoom: 0.55
        cutSides: true
        source: Qt.resolvedUrl("../../widgets/launcher/LauncherView.qml")
        snapshot: true
        refreshKey: root.look
        overrides: ({
                "layout.launcher.resultStyle": root.style,
                "layout.launcher.preview": false,
                "layout.launcher.compactWhenEmpty": false
            })
        samples: ({
                "launcher.query": root.query,
                "launcher.live": Samples.LIVE,
                "launcher.rows": Samples.rows(root.style, root.query, k => I18n.t(k), n => Icons[n] ?? "", id => SettingsStore.get("prefix." + id) ?? "")
            })
    }
}
