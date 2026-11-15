pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.live
import "../../widgets/dashboard/DashboardTabs.js" as DashboardTabs

// Stage of Dashboard: the real dashboard (modules/widgets/dashboard,
// Dashboard.qml by URL with a PreviewContext) in its real host, where it
// opens (the notch, the spotlight or the side sheet), with your live
// widgets: the header with its tabs in your order, the home view as
// configured (the stage with its player, controls, agenda and metrics
// strip, the composed home or your widget grid), your wallpapers and
// metrics. A click on a tab in its header shows that tab here (only the
// widgets tab and the one shown are built); anywhere else opens the Home
// card.
Stage {
    id: stage
    objectName: "dashboardStage"

    readonly property var tabs: DashboardTabs.resolve(SettingsStore.get("layout.dashboard.tabs")).filter(t => t.visible)
    // the tab shown on the stage (falls back to the first visible one)
    property string shown: ""
    readonly property string current: stage.tabs.some(t => t.id === stage.shown) ? stage.shown : (stage.tabs.length > 0 ? stage.tabs[0].id : "widgets")

    // a strip as wide as the page (SettingsPage)
    readonly property bool pageWide: true
    readonly property real preferredHeight: Space.px(250)

    stageHeight: stage.preferredHeight

    LiveHosted {
        id: hosted
        objectName: "dashboardLive"
        anchors.fill: parent
        anchors.topMargin: hosted.host === "notch" ? 0 : Space.s
        surface: "dashboard"
        source: Qt.resolvedUrl("../../widgets/dashboard/Dashboard.qml")
        // its open reveal (StageView) plays before it is measured
        settleMs: 500
        samples: ({
                "dashboard.tab": Math.max(0, DashboardTabs.indexOf(stage.current))
            })
    }

    ViewSpot {
        hosted: hosted
        name: "header"
        keys: ["layout.dashboard.tabs"]
    }
    ViewSpot {
        hosted: hosted
        name: "hero"
        keys: ["layout.dashboard.heroTint", "layout.dashboard.home"]
    }
    ViewSpot {
        hosted: hosted
        name: "player"
        keys: ["layout.dashboard.home"]
    }
    ViewSpot {
        hosted: hosted
        name: "metrics"
        keys: ["layout.dashboard.showMetrics"]
    }

    MouseArea {
        objectName: "dashboardMiniArea"
        x: hosted.frameRect.x
        y: hosted.frameRect.y
        width: hosted.frameRect.width
        height: hosted.frameRect.height
        cursorShape: Qt.PointingHandCursor
        onClicked: SettingsStore.navigate("dashboard", "home", "")
    }

    // the header's tabs: a click shows that tab (over the picture, mapped
    // from the real segments)
    Repeater {
        model: stage.tabs
        delegate: MouseArea {
            id: tabArea
            required property var modelData
            property rect at: Qt.rect(0, 0, 0, 0)
            function measure() {
                const seg = hosted.ready ? hosted.find("dashTab_" + tabArea.modelData.id) : null;
                tabArea.at = seg ? hosted.mapFromView(seg) : Qt.rect(0, 0, 0, 0);
            }
            objectName: "dashboardTab:" + tabArea.modelData.id
            x: hosted.x + tabArea.at.x
            y: hosted.y + tabArea.at.y
            width: tabArea.at.width
            height: tabArea.at.height
            visible: tabArea.at.width > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: stage.shown = tabArea.modelData.id
            Connections {
                target: hosted
                function onReadyChanged() {
                    remeasure.restart();
                }
                function onZoomChanged() {
                    remeasure.restart();
                }
            }
            Connections {
                target: SettingsStore
                function onValueSet() {
                    remeasure.restart();
                }
            }
            Timer {
                id: remeasure
                interval: 450
                onTriggered: tabArea.measure()
            }
        }
    }
}
