pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.shell
import qs.modules.settings.controls
import "../Ui.js" as Ui
import "LayoutSketch.js" as LayoutSketch

// Edge preview of the Layout page: a thumbnail of the screen with the bar,
// dock and notch, and where the launcher, dashboard and OSD open for the
// current config (live; geometry from LayoutSketch / EdgeLayout).
PreviewStage {
    id: root

    property var entry
    stageHeight: 190

    readonly property var refScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : ({
            "width": 1920,
            "height": 1080
        })
    readonly property var env: EdgeService.envFor(root.refScreen)
    readonly property var layoutCfg: Config.layout
    readonly property var items: LayoutSketch.scene(root.env, {
        "launcherHost": root.layoutCfg ? root.layoutCfg.launcher.host : "notch",
        "dashboardHost": root.layoutCfg ? root.layoutCfg.dashboard.host : "notch",
        "sheetSide": root.layoutCfg ? root.layoutCfg.sheet.side : "auto",
        "sheetW": Metrics.sheetW,
        "launcher": {
            "w": Metrics.launcherCompactW,
            "h": Metrics.launcherCompactH
        },
        "dashboard": {
            "w": Metrics.dashWideW,
            "h": Metrics.dashH
        },
        "osdPosition": root.layoutCfg && root.layoutCfg.osd ? root.layoutCfg.osd.position : "auto",
        "osd": {
            "w": Metrics.osdW,
            "h": 48
        }
    })

    readonly property var labels: ({
            "launcher": I18n.t("prefs.layout.preview.launcher"),
            "dashboard": I18n.t("prefs.layout.preview.dashboard"),
            "osd": I18n.t("prefs.layout.preview.osd")
        })

    function fill(id) {
        if (id === "launcher")
            return Ui.alpha(Colors.primary, 0.28);
        if (id === "dashboard")
            return Ui.alpha(Colors.secondary, 0.28);
        if (id === "osd")
            return Ui.alpha(Colors.tertiary, 0.4);
        return Colors.surfaceContainerHighest;
    }

    function stroke(id) {
        if (id === "launcher")
            return Colors.primary;
        if (id === "dashboard")
            return Colors.secondary;
        if (id === "osd")
            return Colors.tertiary;
        return Ui.alpha(Colors.outlineVariant, 0.8);
    }

    Rectangle {
        id: screenBox
        objectName: "layoutPreviewScreen"
        readonly property real k: Math.min((root.width - 40) / root.env.screen.w, (root.height - 36) / root.env.screen.h)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8
        width: root.env.screen.w * k
        height: root.env.screen.h * k
        radius: Math.min(Styling.radius(-4), 8)
        color: Colors.surface
        border.width: 1
        border.color: Ui.alpha(Colors.outlineVariant, 0.7)
        clip: true

        Repeater {
            model: root.items

            Rectangle {
                required property var modelData
                objectName: "layoutPreview_" + modelData.id
                x: modelData.x * screenBox.k
                y: modelData.y * screenBox.k
                width: Math.max(2, modelData.w * screenBox.k)
                height: Math.max(2, modelData.h * screenBox.k)
                radius: Math.min(4, width / 2, height / 2)
                color: root.fill(modelData.id)
                border.width: root.labels[modelData.id] ? 1 : 0
                border.color: root.stroke(modelData.id)

                Text {
                    anchors.centerIn: parent
                    visible: !!root.labels[parent.modelData.id] && parent.width > implicitWidth + 4
                    text: root.labels[parent.modelData.id] || ""
                    color: Colors.overSurfaceVariant
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-4)
                }
            }
        }
    }
}
