import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import "ExtrasModel.js" as ExtrasModel

// Bottom line of a catalog card, one look per card state:
//   installed   - success pill + where it came from
//   selectable  - download size (+ "Recommended"), select check on the right
//   installing  - phase, percent, cancel and an animated bar
//   failed      - "Failed" pill · Retry / Update system and retry · Log
//   unavailable - why it can't be installed here ("Not available on Fedora")
Item {
    id: root

    property string cardState: "selectable"
    property var entry: ({})
    property var status: null
    property var progress: null
    property color accent: Colors.primary
    property bool selected: false
    property bool hovered: false
    signal toggled
    signal retry
    signal upgradeRetry
    signal showLog
    signal cancel

    readonly property bool needsSync: !!root.progress && root.progress.reason === "needs_sync"
    readonly property bool canCancel: ExtrasModel.cancellable(root.progress)
    readonly property string distro: ["arch", "fedora", "nixos"].includes(ExtrasService.platform.distro) ? ExtrasService.platform.distro : "other"
    readonly property var phase: ExtrasModel.phaseText(root.progress ? root.progress.phase : "")

    implicitHeight: Space.chip - Space.xs

    component LinkButton: KitText {
        id: link
        signal clicked
        role: "caption"
        font.weight: Look.activeLabelWeight
        color: linkArea.containsMouse ? Type.text : Type.secondary
        font.underline: linkArea.containsMouse
        MouseArea {
            id: linkArea
            anchors.fill: parent
            anchors.margins: -Space.xs
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    component Muted: KitText {
        role: "caption"
        color: Type.secondary
    }

    // installed
    Row {
        visible: root.cardState === "installed"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Space.s
        StatusPill {
            id: installedPill
            objectName: "installedPill"
            icon: "check"
            text: I18n.t("extras.ui.installed")
            accent: Colors.green
        }
        Muted {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - installedPill.width - Space.s
            text: root.status && root.status.source ? I18n.t("extras.ui.source." + root.status.source) : ""
        }
    }

    // selectable
    Item {
        visible: root.cardState === "selectable"
        anchors.fill: parent

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            Row {
                visible: !!root.entry.size
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.downloadSimple
                    role: "caption"
                    tone: "secondary"
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
                accent: Type.secondary
            }
        }
        CheckToggle {
            objectName: "toggle"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.selected
            hovered: root.hovered
            onToggled: root.toggled()
        }
    }

    // installing
    Item {
        visible: root.cardState === "installing"
        anchors.fill: parent

        Muted {
            objectName: "phaseText"
            anchors.left: parent.left
            anchors.right: pct.left
            anchors.rightMargin: Space.s
            text: {
                const p = root.progress;
                if (!p)
                    return I18n.t("extras.ui.starting");
                if (p.state === "queued")
                    return I18n.t("extras.ui.queued");
                if (root.phase.key === "")
                    return root.phase.detail || I18n.t("extras.ui.installing");
                return root.phase.detail ? I18n.t(root.phase.key + ".detail", root.phase.detail) : I18n.t(root.phase.key);
            }
        }
        KitText {
            id: pct
            anchors.right: stop.left
            anchors.rightMargin: Space.xs
            visible: !!root.progress && root.progress.percent >= 0 && root.progress.state === "running"
            role: "caption"
            tabular: true
            text: root.progress ? root.progress.percent + "%" : ""
            font.weight: Look.activeLabelWeight
            color: Type.progress
        }
        Icon {
            id: stop
            objectName: "cancelButton"
            anchors.right: parent.right
            y: -1
            visible: !!root.progress
            enabled: root.canCancel
            opacity: enabled ? (stopArea.containsMouse ? 1 : 0.7) : 0.3
            icon: Icons.xCircle
            color: stopArea.containsMouse ? Type.danger : Type.secondary
            MouseArea {
                id: stopArea
                anchors.fill: parent
                anchors.margins: -Space.xs
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
            // queued: an empty track; running without a percentage: sliding
            percent: !root.progress ? -1 : (root.progress.state !== "running" ? 0 : root.progress.percent)
        }
    }

    // failed (the description above says why)
    Row {
        visible: root.cardState === "failed"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: Space.m
        StatusPill {
            id: failedPill
            objectName: "failedPill"
            icon: "warning"
            text: I18n.t("extras.ui.failed")
            accent: Type.danger
        }
        LinkButton {
            id: retryLink
            objectName: "retryButton"
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - failedPill.width - Space.m - (logLink.visible ? logLink.implicitWidth + Space.m : 0))
            elide: Text.ElideRight
            text: root.needsSync ? I18n.t("extras.ui.update_retry") : I18n.t("extras.ui.retry")
            onClicked: root.needsSync ? root.upgradeRetry() : root.retry()
            HoverHandler {
                id: retryHover
            }
            StyledToolTip {
                show: retryHover.hovered && retryLink.truncated
                tooltipText: retryLink.text
            }
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
        objectName: "unavailableText"
        visible: root.cardState === "unavailable"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: I18n.t(ExtrasModel.unavailableKey(root.status ? root.status.reason : ""), I18n.t("extras.ui.distro." + root.distro))
    }
}
