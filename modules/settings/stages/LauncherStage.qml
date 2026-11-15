pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "LauncherSamples.js" as Samples

// Stage of Launcher: the real launcher (modules/widgets/launcher,
// LauncherView by URL with a PreviewContext) in its real host, where it
// opens on your screen: hanging from the notch, centred (spotlight) or on
// the side sheet. It answers a believable search: your installed apps
// (the apps provider, live) and one sample row of every other provider
// that is on, in their order (LauncherSamples.js), in the result style,
// with or without icons and the detail pane, the tab prefixes in the
// field. A short stage keeps it readable and lets its bottom edge cut it.
// A click opens the Results card.
Stage {
    id: stage
    objectName: "launcherStage"

    readonly property string style: String(SettingsStore.get("layout.launcher.resultStyle") || "list")
    readonly property var appNames: (AppSearch.getAllApps ? AppSearch.getAllApps() : []).slice(0, 8).map(a => a.name)
    readonly property string query: Samples.query(stage.appNames, stage.style)

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Space.px(250)

    stageHeight: stage.preferredHeight

    LiveHosted {
        id: hosted
        objectName: "launcherLive"
        anchors.fill: parent
        surface: "launcher"
        source: Qt.resolvedUrl("../../widgets/launcher/LauncherView.qml")
        // readable: under ~0.6 the stage's edge cuts it instead
        minZoom: 0.6
        maxZoom: 0.9
        samples: ({
                "launcher.query": stage.query,
                "launcher.live": Samples.LIVE,
                "launcher.rows": Samples.rows(stage.style, stage.query, k => I18n.t(k), n => Icons[n] ?? "", id => SettingsStore.get("prefix." + id) ?? "")
            })
    }

    ViewSpot {
        hosted: hosted
        name: "launcherSearchInput"
        keys: ["prefix.clipboard", "prefix.emoji", "prefix.tmux", "prefix.notes", "layout.launcher.compactWhenEmpty"]
    }
    ViewSpot {
        hosted: hosted
        name: "launcherResults"
        keys: ["prefix.launcher.disabled", "prefix.launcher.order", "layout.launcher.resultStyle", "layout.launcher.icons", "prefix.launcher.filesInMixed"]
    }
    ViewSpot {
        hosted: hosted
        name: "launcherGrid"
        keys: ["layout.launcher.resultStyle"]
    }
    ViewSpot {
        hosted: hosted
        name: "launcherPreview"
        keys: ["layout.launcher.preview"]
    }

    MouseArea {
        objectName: "launcherMiniArea"
        x: hosted.frameRect.x
        y: hosted.frameRect.y
        width: hosted.frameRect.width
        height: hosted.frameRect.height
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.navigate("launcher", "appearance", "")
    }
}
