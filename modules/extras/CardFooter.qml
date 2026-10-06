import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "ExtrasModel.js" as ExtrasModel
import "../settings/Ui.js" as Ui

// Bottom line of a catalog card, one look per card state:
//   installed   - success pill + where it came from
//   selectable  - download size (+ "Recommended")
//   installing  - phase, percent, cancel and an animated bar
//   failed      - Retry / Update system and retry · Log
//   unavailable - "Not available on <distro>"
Item {
    id: root

    property string cardState: "selectable"
    property var entry: ({})
    property var status: null
    property var progress: null
    property color accent: Colors.primary
    signal retry
    signal upgradeRetry
    signal showLog
    signal cancel

    readonly property bool needsSync: !!root.progress && root.progress.reason === "needs_sync"
    readonly property bool canCancel: ExtrasModel.cancellable(root.progress)

    implicitHeight: root.cardState === "installing" ? 28 : 26

    component LinkButton: Text {
        id: link
        signal clicked
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.weight: Font.DemiBold
        color: linkArea.containsMouse ? Colors.primary : Ui.mix(Colors.primary, Colors.overBackground, 0.25)
        font.underline: linkArea.containsMouse
        MouseArea {
            id: linkArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    component Muted: Text {
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
        elide: Text.ElideRight
    }

    // installed
    Row {
        visible: root.cardState === "installed"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 8
        StatusPill {
            id: installedPill
            objectName: "installedPill"
            icon: "check"
            text: I18n.t("extras.ui.installed")
            accent: Colors.green
        }
        Muted {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - installedPill.width - 8
            text: root.status && root.status.source ? I18n.t("extras.ui.source." + root.status.source) : ""
        }
    }

    // selectable
    Row {
        visible: root.cardState === "selectable"
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Row {
            visible: !!root.entry.size
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.downloadSimple
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
            Muted {
                objectName: "sizeText"
                text: root.entry.size || ""
            }
        }
        StatusPill {
            visible: !!root.entry.recommended
            icon: "sparkle"
            text: I18n.t("extras.ui.recommended")
            accent: Colors.tertiary
        }
    }

    // installing
    Item {
        visible: root.cardState === "installing"
        anchors.fill: parent

        Muted {
            id: phase
            anchors.left: parent.left
            anchors.right: pct.left
            anchors.rightMargin: 8
            y: 0
            text: {
                const p = root.progress;
                if (!p || p.state === "queued")
                    return I18n.t("extras.ui.queued");
                return p.phase || I18n.t("extras.ui.installing");
            }
        }
        Text {
            id: pct
            anchors.right: stop.left
            anchors.rightMargin: 6
            y: 0
            visible: !!root.progress && root.progress.percent >= 0 && root.progress.state === "running"
            text: root.progress ? root.progress.percent + "%" : ""
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.weight: Font.DemiBold
            color: root.accent
        }
        Text {
            id: stop
            objectName: "cancelButton"
            anchors.right: parent.right
            y: -1
            enabled: root.canCancel
            opacity: enabled ? (stopArea.containsMouse ? 1 : 0.7) : 0.3
            text: Icons.xCircle
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(0)
            color: stopArea.containsMouse ? Colors.error : Colors.overSurfaceVariant
            MouseArea {
                id: stopArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: root.canCancel ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.canCancel)
                    root.cancel()
            }
            StyledToolTip {
                show: stopArea.containsMouse
                tooltipText: root.canCancel ? I18n.t("extras.ui.cancel") : I18n.t("extras.ui.cancel_locked")
            }
        }
        ProgressTrack {
            objectName: "progressTrack"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            accent: root.accent
            // queued: an empty track; running without a percentage: sliding
            percent: !root.progress || root.progress.state !== "running" ? 0 : root.progress.percent
        }
    }

    // failed (the card shows the "Failed" pill and the reason above)
    Row {
        visible: root.cardState === "failed"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 14
        LinkButton {
            objectName: "retryButton"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - (logLink.visible ? logLink.implicitWidth + 14 : 0))
            elide: Text.ElideRight
            text: root.needsSync ? I18n.t("extras.ui.update_retry") : I18n.t("extras.ui.retry")
            onClicked: root.needsSync ? root.upgradeRetry() : root.retry()
        }
        LinkButton {
            id: logLink
            objectName: "logButton"
            visible: !!root.progress && !!root.progress.job
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("extras.ui.log")
            onClicked: root.showLog()
        }
    }

    // unavailable
    Muted {
        visible: root.cardState === "unavailable"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: I18n.t("extras.ui.unavailable", I18n.t("extras.ui.distro." + (["arch", "fedora", "nixos"].includes(ExtrasService.platform.distro) ? ExtrasService.platform.distro : "other")))
    }
}
