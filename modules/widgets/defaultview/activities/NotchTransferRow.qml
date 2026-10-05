import QtQuick
import Quickshell.Widgets
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import "NotchActivities.js" as NotchActivities
import "../../../services/activities/TransferModel.js" as TransferModel

// One download/copy/update in the expanded notch: app icon, title (middle
// elided), progress bar, sizes · speed and ETA or state, and actions (open
// folder; pause/resume/cancel when the source supports them).
Item {
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
    readonly property color accent: row.t.state === "failed" ? Colors.error : (row.t.state === "done" ? Colors.green : (row.t.state === "running" ? Colors.primary : Colors.overSurfaceVariant))
    readonly property real iconSize: Math.round(Styling.fontSize(6))
    readonly property real pad: Math.round(Styling.fontSize(-4))

    implicitHeight: column.implicitHeight + row.pad * 2

    // Finished items fade out while the backend lingers them
    opacity: row.t.state === "done" ? 0.55 : 1
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration * 4
        }
    }

    Item {
        id: iconBox
        x: 0
        y: row.pad
        width: row.iconSize
        height: row.iconSize

        IconImage {
            id: appIcon
            anchors.fill: parent
            source: ActivityService.iconUrl(row.t.appIcon || "")
            visible: status === Image.Ready
            asynchronous: true
        }
        Text {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: row.t.state === "done" ? Icons.accept : (row.t.kind === "copy" ? Icons.copy : (row.t.kind === "sync" || row.t.kind === "update" ? Icons.sync : Icons.downloadSimple))
            font.family: Icons.font
            font.pixelSize: Math.round(row.iconSize * 0.75)
            color: row.accent
        }
    }

    Column {
        id: column
        anchors.left: iconBox.right
        anchors.leftMargin: row.pad * 2
        anchors.right: parent.right
        y: row.pad
        spacing: Math.round(row.pad * 0.8)

        Item {
            width: parent.width
            height: Math.max(titleText.implicitHeight, actions.implicitHeight)

            Text {
                id: titleText
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: row.pad
                anchors.verticalCenter: parent.verticalCenter
                text: row.t.title || row.t.app || ""
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: Colors.overBackground
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(row.pad / 2)

                NotchIconButton {
                    visible: !row.finished && row.t.state !== "paused" && (row.t.actions || []).indexOf("suspend") !== -1
                    icon: Icons.pause
                    tooltip: I18n.t("activities.pause")
                    onClicked: ActivityService.transferAction(row.t, "suspend")
                }
                NotchIconButton {
                    visible: !row.finished && row.t.state === "paused" && (row.t.actions || []).indexOf("resume") !== -1
                    icon: Icons.play
                    tooltip: I18n.t("activities.resume")
                    onClicked: ActivityService.transferAction(row.t, "resume")
                }
                NotchIconButton {
                    visible: !!(row.t.path || row.t.dir || row.t.openUrl || row.t.source === "notificationProgress")
                    icon: Icons.folder
                    tooltip: I18n.t("activities.open_folder")
                    onClicked: ActivityService.transferAction(row.t, "open")
                }
                NotchIconButton {
                    visible: !row.finished && (row.t.actions || []).indexOf("cancel") !== -1
                    icon: Icons.cancel
                    tone: "error"
                    tooltip: I18n.t("activities.cancel")
                    onClicked: ActivityService.transferAction(row.t, "cancel")
                }
            }
        }

        NotchProgressBar {
            width: parent.width
            progress: row.progressValue
            accent: row.accent
            running: row.t.state === "running"
        }

        Item {
            width: parent.width
            height: statusLeft.implicitHeight

            Text {
                id: statusLeft
                anchors.left: parent.left
                anchors.right: statusRight.left
                anchors.rightMargin: row.pad
                text: row.status.left
                elide: Text.ElideRight
                color: Colors.overSurfaceVariant
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.features: ({
                        "tnum": 1
                    })
            }
            Text {
                id: statusRight
                anchors.right: parent.right
                text: row.status.right
                color: row.status.tone === "error" ? Colors.error : (row.status.tone === "done" ? Colors.green : Colors.overSurfaceVariant)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: row.status.tone === "normal" ? Font.Normal : Font.DemiBold
                font.features: ({
                        "tnum": 1
                    })
            }
        }
    }
}
