pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.components.kit
import "NotchActivities.js" as NotchActivities
import "../../../services/activities/TransferModel.js" as TransferModel

// One download/copy/update in the expanded notch: a ListRow (app art, name,
// sizes · speed · ETA or state, actions: pause / resume / open folder /
// cancel when the source supports them) over a ProgressLine aligned with
// the text.
Column {
    id: row

    property var transfer: null
    property bool showSpeed: true

    readonly property var t: row.transfer || ({})
    readonly property real progressValue: TransferModel.progress(row.t)
    readonly property var status: NotchActivities.transferStatus(row.t, TransferModel, row.showSpeed, {
        left: I18n.t("activities.left"),
        paused: I18n.t("activities.paused"),
        queued: I18n.t("activities.queued"),
        failed: I18n.t("activities.failed"),
        done: I18n.t("activities.done")
    })
    readonly property bool finished: row.t.state === "done" || row.t.state === "failed"
    readonly property var actionList: row.t.actions || []

    spacing: 0
    // Finished items fade out while the backend lingers them
    opacity: row.t.state === "done" ? 0.55 : 1
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration * 4
        }
    }

    ListRow {
        id: listRow
        width: parent.width
        title: row.t.title || row.t.app || ""
        subtitle: [row.status.left, row.status.right].filter(s => !!s).join(" · ")
        leading: Component {
            Art {
                width: Space.controlS
                height: Space.controlS
                source: ActivityService.iconUrl(row.t.appIcon || "")
                icon: row.t.state === "done" ? Icons.accept : (row.t.kind === "copy" ? Icons.copy : (row.t.kind === "sync" || row.t.kind === "update" ? Icons.sync : Icons.downloadSimple))
            }
        }
        trailing: Component {
            Row {
                spacing: Space.xs

                IconButton {
                    objectName: "transferPause"
                    size: "s"
                    visible: !row.finished && row.t.state !== "paused" && row.actionList.indexOf("suspend") !== -1
                    icon: Icons.pause
                    Accessible.name: I18n.t("activities.pause")
                    onClicked: ActivityService.transferAction(row.t, "suspend")
                }
                IconButton {
                    objectName: "transferResume"
                    size: "s"
                    visible: !row.finished && row.t.state === "paused" && row.actionList.indexOf("resume") !== -1
                    icon: Icons.play
                    Accessible.name: I18n.t("activities.resume")
                    onClicked: ActivityService.transferAction(row.t, "resume")
                }
                IconButton {
                    objectName: "transferOpen"
                    size: "s"
                    visible: !!(row.t.path || row.t.dir || row.t.openUrl || row.t.source === "notificationProgress")
                    icon: Icons.folder
                    Accessible.name: I18n.t("activities.open_folder")
                    onClicked: ActivityService.transferAction(row.t, "open")
                }
                IconButton {
                    objectName: "transferCancel"
                    size: "s"
                    visible: !row.finished && row.actionList.indexOf("cancel") !== -1
                    icon: Icons.cancel
                    Accessible.name: I18n.t("activities.cancel")
                    onClicked: ActivityService.transferAction(row.t, "cancel")
                }
            }
        }
    }

    // Under the text column (art + its gap), not under the art
    ProgressLine {
        x: Space.s + Space.controlS + Space.m
        width: parent.width - x - Space.s
        visible: !row.finished
        value: row.progressValue < 0 ? 0 : row.progressValue
    }
    Item {
        width: 1
        height: Space.s
    }
}
